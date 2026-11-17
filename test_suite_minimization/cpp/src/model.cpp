#include "minimizer/model.hpp"

#include <stdexcept>

namespace minimizer {
namespace {

int integer(const Json& value) {
    return static_cast<int>(value.as_number());
}

std::optional<Operand> operand(const Json& value) {
    if (value.is_null()) return std::nullopt;
    Operand result;
    result.kind = value.at("kind").as_string();
    if (value.contains("table")) result.table = value.at("table").as_string();
    if (value.contains("column")) result.column = value.at("column").as_string();
    if (value.contains("type")) result.type = value.at("type").as_string();
    if (value.contains("value")) result.value = value.at("value").as_string();
    return result;
}

std::vector<Row> rows(const Json& value) {
    std::vector<Row> result;
    for (const Json& row_json : value.as_array()) {
        Row row;
        row.table = row_json.at("table").as_string();
        for (const auto& entry : row_json.at("values").as_object()) {
            if (entry.second.is_null()) row.values.emplace(entry.first, std::nullopt);
            else row.values.emplace(entry.first, entry.second.as_string());
        }
        result.push_back(std::move(row));
    }
    return result;
}

}  // namespace

Input parse_input(const Json& root) {
    Input input;
    input.format_version = integer(root.at("formatVersion"));
    if (input.format_version != 1) {
        throw std::runtime_error("unsupported formatVersion: " + std::to_string(input.format_version));
    }
    input.snapshot_sha256 = root.at("snapshotSha256").as_string();

    for (const Json& check_json : root.at("schema").at("checks").as_array()) {
        Check check;
        check.id = check_json.at("id").as_string();
        check.table = check_json.at("table").as_string();
        check.expression = check_json.at("expression").as_string();
        check.supported = check_json.at("supported").as_bool();
        if (check_json.contains("unsupportedReason")) check.unsupported_reason = check_json.at("unsupportedReason").as_string();
        if (check_json.contains("operator")) check.op = check_json.at("operator").as_string();
        if (check_json.contains("left")) check.left = operand(check_json.at("left"));
        if (check_json.contains("right")) check.right = operand(check_json.at("right"));
        input.checks.push_back(std::move(check));
    }

    for (const Json& test_json : root.at("tests").as_array()) {
        Test test;
        test.id = test_json.at("id").as_string();
        test.expected_result = test_json.at("expectedResult").as_bool();
        if (test_json.contains("postgresValidation")) {
            const Json& validation = test_json.at("postgresValidation");
            if (validation.contains("phase")) {
                test.validation_phase = validation.at("phase").as_string();
            }
            if (validation.contains("actualResult") && !validation.at("actualResult").is_null()) {
                test.validation_observed = true;
                test.validation_actual_result = validation.at("actualResult").as_bool();
            }
            if (validation.contains("sqlstate")) {
                test.validation_sqlstate = validation.at("sqlstate").as_string();
            }
            if (validation.contains("constraintName")) {
                test.validation_constraint = validation.at("constraintName").as_string();
            }
        }
        for (const Json& requirement : test_json.at("coveredRequirementIds").as_array()) {
            test.requirement_ids.push_back(requirement.as_string());
        }
        test.state = rows(test_json.at("state"));
        test.data = rows(test_json.at("data"));
        test.state_insert_count = integer(test_json.at("stateInsertCount"));
        test.data_insert_count = integer(test_json.at("dataInsertCount"));
        input.tests.push_back(std::move(test));
    }
    return input;
}

}  // namespace minimizer
