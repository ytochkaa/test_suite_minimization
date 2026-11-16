#include "minimizer/boundary.hpp"

#include <algorithm>
#include <cctype>
#include <stdexcept>

namespace minimizer {
namespace {

using WideInteger = __int128_t;

bool integer_type(const std::string& type) {
    return type == "IntDataType" || type == "BigIntDataType" || type == "NumericValue";
}

WideInteger parse_integer(const std::string& text) {
    if (text.empty()) throw std::runtime_error("empty integer value");
    std::size_t position = 0;
    bool negative = text[position] == '-';
    if (negative) ++position;
    if (position == text.size()) throw std::runtime_error("invalid integer: " + text);
    WideInteger value = 0;
    for (; position < text.size(); ++position) {
        unsigned char character = static_cast<unsigned char>(text[position]);
        if (!std::isdigit(character)) throw std::runtime_error("non-integer value: " + text);
        value = value * 10 + (character - '0');
    }
    return negative ? -value : value;
}

struct ResolvedValue {
    bool present = false;
    bool is_null = false;
    std::string text;
};

ResolvedValue value(const Operand& operand, const Row& row) {
    if (operand.kind == "constant") return {true, false, operand.value};
    if (operand.kind != "column" || operand.table != row.table) return {};
    auto found = row.values.find(operand.column);
    if (found == row.values.end()) return {};
    if (!found->second.has_value()) return {true, true, {}};
    return {true, false, *found->second};
}

std::string truth(const std::string& op, WideInteger left, WideInteger right) {
    bool result;
    if (op == "<") result = left < right;
    else if (op == "<=") result = left <= right;
    else if (op == ">") result = left > right;
    else if (op == ">=") result = left >= right;
    else throw std::runtime_error("unsupported operator: " + op);
    return result ? "true" : "false";
}

std::optional<std::string> boundary_for(const Check& check, const Row& row) {
    if (!check.left || !check.right || row.table != check.table) return std::nullopt;
    const Operand& left_operand = *check.left;
    const Operand& right_operand = *check.right;
    if (!integer_type(left_operand.type) || !integer_type(right_operand.type)) return std::nullopt;

    ResolvedValue left = value(left_operand, row);
    ResolvedValue right = value(right_operand, row);
    if (!left.present || !right.present) return std::nullopt;
    bool left_null = left.is_null;
    bool right_null = right.is_null;
    if (left_null || right_null) {
        std::string category = left_null && right_null ? "both-null" : (left_null ? "left-null" : "right-null");
        return "B|" + check.id + "|" + category + "|unknown";
    }

    WideInteger left_number = parse_integer(left.text);
    WideInteger right_number = parse_integer(right.text);
    WideInteger distance = left_number - right_number;
    std::string category;
    if (distance == -1) category = "-1";
    else if (distance == 0) category = "0";
    else if (distance == 1) category = "+1";
    else return std::nullopt;
    return "B|" + check.id + "|" + category + "|" + truth(check.op, left_number, right_number);
}

}  // namespace

Coverage build_coverage(const Input& input) {
    Coverage coverage;
    for (const Check& check : input.checks) {
        if (!check.supported) {
            coverage.unsupported_checks.push_back(check.id + ": " + check.unsupported_reason);
        }
    }

    std::set<std::string> test_ids;
    for (const Test& test : input.tests) {
        if (!test_ids.insert(test.id).second) throw std::runtime_error("duplicate test id: " + test.id);
        std::set<std::string>& test_coverage = coverage.by_test[test.id];
        for (const std::string& requirement : test.requirement_ids) {
            std::string key = "R|" + requirement;
            test_coverage.insert(key);
            coverage.requirements.insert(key);
        }
        for (const Row& row : test.data) {
            for (const Check& check : input.checks) {
                if (!check.supported) continue;
                auto obligation = boundary_for(check, row);
                if (obligation) {
                    test_coverage.insert(*obligation);
                    coverage.boundaries.insert(*obligation);
                }
            }
        }
    }
    return coverage;
}

}  // namespace minimizer
