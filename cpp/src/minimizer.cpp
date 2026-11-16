#include "minimizer/minimizer.hpp"

#include <algorithm>
#include <chrono>
#include <map>
#include <set>
#include <stdexcept>

namespace minimizer {
namespace {

std::set<std::string> unite(const std::set<std::string>& left, const std::set<std::string>& right) {
    std::set<std::string> result = left;
    result.insert(right.begin(), right.end());
    return result;
}

std::set<std::string> difference(const std::set<std::string>& left, const std::set<std::string>& right) {
    std::set<std::string> result;
    std::set_difference(left.begin(), left.end(), right.begin(), right.end(), std::inserter(result, result.end()));
    return result;
}

std::set<std::string> coverage_of(const std::vector<std::string>& selected, const Coverage& coverage) {
    std::set<std::string> result;
    for (const std::string& test_id : selected) {
        const auto& values = coverage.by_test.at(test_id);
        result.insert(values.begin(), values.end());
    }
    return result;
}

Json strings(const std::set<std::string>& values) {
    Json::Array result;
    for (const std::string& value : values) result.emplace_back(value);
    return Json(std::move(result));
}

Json strings(const std::vector<std::string>& values) {
    Json::Array result;
    for (const std::string& value : values) result.emplace_back(value);
    return Json(std::move(result));
}

}  // namespace

Json minimize(const Input& input, const Coverage& coverage) {
    const auto started = std::chrono::steady_clock::now();
    const std::set<std::string> universe = unite(coverage.requirements, coverage.boundaries);
    std::map<std::string, int> witness_count;
    std::map<std::string, std::string> sole_witness;
    for (const auto& entry : coverage.by_test) {
        for (const std::string& obligation : entry.second) {
            ++witness_count[obligation];
            sole_witness[obligation] = entry.first;
        }
    }

    std::vector<std::string> selected;
    std::set<std::string> selected_set;
    std::map<std::string, std::string> reasons;
    for (const auto& entry : witness_count) {
        if (entry.second == 1) {
            const std::string& test_id = sole_witness.at(entry.first);
            if (selected_set.insert(test_id).second) selected.push_back(test_id);
            reasons[test_id] = "unique witness for " + entry.first;
        }
    }

    std::set<std::string> covered = coverage_of(selected, coverage);
    while (covered != universe) {
        const Test* best = nullptr;
        std::size_t best_gain = 0;
        int best_inserts = 0;
        for (const Test& test : input.tests) {
            if (selected_set.count(test.id) != 0) continue;
            std::size_t gain = difference(coverage.by_test.at(test.id), covered).size();
            int inserts = test.state_insert_count + test.data_insert_count;
            if (best == nullptr || gain > best_gain
                    || (gain == best_gain && inserts < best_inserts)
                    || (gain == best_gain && inserts == best_inserts && test.id < best->id)) {
                best = &test;
                best_gain = gain;
                best_inserts = inserts;
            }
        }
        if (best == nullptr || best_gain == 0) {
            throw std::runtime_error("cannot cover all obligations from the input matrix");
        }
        selected.push_back(best->id);
        selected_set.insert(best->id);
        reasons[best->id] = "greedy gain " + std::to_string(best_gain);
        covered = unite(covered, coverage.by_test.at(best->id));
    }

    for (std::size_t offset = selected.size(); offset > 0; --offset) {
        std::size_t index = offset - 1;
        std::vector<std::string> candidate = selected;
        candidate.erase(candidate.begin() + static_cast<std::ptrdiff_t>(index));
        if (coverage_of(candidate, coverage) == universe) {
            reasons.erase(selected[index]);
            selected_set.erase(selected[index]);
            selected = std::move(candidate);
        }
    }

    const std::set<std::string> verified = coverage_of(selected, coverage);
    const std::set<std::string> lost = difference(universe, verified);
    if (!lost.empty()) throw std::runtime_error("independent verification found lost obligations");

    std::vector<std::string> excluded;
    int final_state_inserts = 0;
    int final_data_inserts = 0;
    int original_state_inserts = 0;
    int original_data_inserts = 0;
    for (const Test& test : input.tests) {
        original_state_inserts += test.state_insert_count;
        original_data_inserts += test.data_insert_count;
        if (selected_set.count(test.id) != 0) {
            final_state_inserts += test.state_insert_count;
            final_data_inserts += test.data_insert_count;
        } else {
            excluded.push_back(test.id);
        }
    }

    Json::Object reason_json;
    for (const std::string& test_id : selected) reason_json.emplace(test_id, reasons.at(test_id));
    for (const std::string& test_id : excluded) reason_json.emplace(test_id, "redundant for preserved obligations");

    Json::Array unsupported;
    for (const std::string& value : coverage.unsupported_checks) unsupported.emplace_back(value);

    const auto elapsed = std::chrono::duration_cast<std::chrono::nanoseconds>(
            std::chrono::steady_clock::now() - started).count();
    Json::Object report;
    report.emplace("formatVersion", 1);
    report.emplace("snapshotSha256", input.snapshot_sha256);
    report.emplace("selectedTestIds", strings(selected));
    report.emplace("excludedTestIds", strings(excluded));
    report.emplace("reasons", Json(std::move(reason_json)));
    report.emplace("originalTestCount", static_cast<long long>(input.tests.size()));
    report.emplace("selectedTestCount", static_cast<long long>(selected.size()));
    report.emplace("originalStateInsertCount", original_state_inserts);
    report.emplace("selectedStateInsertCount", final_state_inserts);
    report.emplace("originalDataInsertCount", original_data_inserts);
    report.emplace("selectedDataInsertCount", final_data_inserts);
    report.emplace("requirementsBefore", strings(coverage.requirements));
    report.emplace("requirementsAfter", strings(difference(verified, coverage.boundaries)));
    report.emplace("boundariesBefore", strings(coverage.boundaries));
    std::set<std::string> verified_boundaries;
    std::set_intersection(verified.begin(), verified.end(), coverage.boundaries.begin(), coverage.boundaries.end(),
                          std::inserter(verified_boundaries, verified_boundaries.end()));
    report.emplace("boundariesAfter", strings(verified_boundaries));
    report.emplace("lostObligations", strings(lost));
    report.emplace("unsupportedChecks", Json(std::move(unsupported)));
    report.emplace("selectionNanoseconds", static_cast<long long>(elapsed));
    report.emplace("verified", true);
    return Json(std::move(report));
}

}  // namespace minimizer
