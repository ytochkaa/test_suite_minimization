#include "minimizer/boundary.hpp"
#include "minimizer/json.hpp"
#include "minimizer/minimizer.hpp"
#include "minimizer/model.hpp"

#include <iostream>
#include <set>
#include <stdexcept>
#include <string>

namespace {

void require(bool condition, const std::string& message) {
    if (!condition) throw std::runtime_error(message);
}

minimizer::Json run(const std::string& json) {
    minimizer::Input input = minimizer::parse_input(minimizer::Json::parse(json));
    minimizer::Coverage coverage = minimizer::build_coverage(input);
    return minimizer::minimize(input, coverage);
}

const char* basic_fixture() {
    return R"JSON({
      "formatVersion":1,
      "snapshotSha256":"fixture-basic",
      "schema":{"checks":[
        {"id":"amount_min","table":"sample","expression":"amount >= 10","supported":true,
         "operator":">=","left":{"kind":"column","table":"sample","column":"amount","type":"IntDataType"},
         "right":{"kind":"constant","value":"10","type":"NumericValue"}}
      ]},
      "tests":[
        {"id":"T1","expectedResult":false,
         "postgresValidation":{"phase":"data","actualResult":false,"sqlstate":"23514","constraintName":"amount_min"},
         "coveredRequirementIds":["R_NEG"],"state":[],
         "data":[{"table":"sample","values":{"amount":"9"}}],"stateInsertCount":0,"dataInsertCount":1},
        {"id":"T2","expectedResult":true,
         "postgresValidation":{"phase":"data","actualResult":true,"sqlstate":"","constraintName":""},
         "coveredRequirementIds":["R_POS"],"state":[],
         "data":[{"table":"sample","values":{"amount":"10"}}],"stateInsertCount":0,"dataInsertCount":1},
        {"id":"T3","expectedResult":true,
         "postgresValidation":{"phase":"data","actualResult":true,"sqlstate":"","constraintName":""},
         "coveredRequirementIds":["R_POS"],"state":[],
         "data":[{"table":"sample","values":{"amount":"11"}}],"stateInsertCount":0,"dataInsertCount":1},
        {"id":"T4","expectedResult":true,
         "postgresValidation":{"phase":"data","actualResult":true,"sqlstate":"","constraintName":""},
         "coveredRequirementIds":["R_POS"],"state":[],
         "data":[{"table":"sample","values":{"amount":"30"}}],"stateInsertCount":3,"dataInsertCount":1}
      ]
    })JSON";
}

void test_boundary_preservation() {
    minimizer::Json report = run(basic_fixture());
    require(report.at("verified").as_bool(), "report must be verified");
    require(static_cast<int>(report.at("selectedTestCount").as_number()) == 3, "three boundary witnesses must remain");
    std::set<std::string> selected;
    for (const minimizer::Json& value : report.at("selectedTestIds").as_array()) selected.insert(value.as_string());
    require(selected == std::set<std::string>({"T1", "T2", "T3"}), "all three boundary witnesses must remain");
    require(report.at("excludedTestIds").as_array()[0].as_string() == "T4", "non-boundary duplicate must be removed");
    require(report.at("boundariesBefore").as_array().size() == 3, "-1, 0 and +1 must be detected");
    require(report.at("lostObligations").as_array().empty(), "no obligation may be lost");
}

void test_null_and_bigint() {
    const std::string fixture = R"JSON({
      "formatVersion":1,"snapshotSha256":"fixture-null",
      "schema":{"checks":[
        {"id":"limit","table":"sample","expression":"x >= y","supported":true,"operator":">=",
         "left":{"kind":"column","table":"sample","column":"x","type":"BigIntDataType"},
         "right":{"kind":"column","table":"sample","column":"y","type":"BigIntDataType"}}
      ]},
      "tests":[
        {"id":"T1","expectedResult":true,"coveredRequirementIds":["R1"],"state":[],
         "postgresValidation":{"phase":"data","actualResult":true,"sqlstate":"","constraintName":""},
         "data":[{"table":"sample","values":{"x":null,"y":"1"}}],"stateInsertCount":0,"dataInsertCount":1},
        {"id":"T2","expectedResult":true,"coveredRequirementIds":["R1"],"state":[],
         "postgresValidation":{"phase":"data","actualResult":true,"sqlstate":"","constraintName":""},
         "data":[{"table":"sample","values":{"x":"9223372036854775807","y":"-9223372036854775808"}}],
         "stateInsertCount":0,"dataInsertCount":1}
      ]})JSON";
    minimizer::Input input = minimizer::parse_input(minimizer::Json::parse(fixture));
    minimizer::Coverage coverage = minimizer::build_coverage(input);
    require(coverage.boundaries.count("B|limit|left-null|unknown") == 1, "NULL must be a separate category");
    require(coverage.boundaries.size() == 1, "wide non-neighbour distance must not become a boundary");
    minimizer::Json report = minimizer::minimize(input, coverage);
    require(report.at("selectedTestCount").as_number() == 1, "unique NULL witness is sufficient");
}

void test_foreign_key_failure_does_not_count_as_check_boundary() {
    const std::string fixture = R"JSON({
      "formatVersion":1,"snapshotSha256":"fixture-masked-boundary",
      "schema":{"checks":[
        {"id":"amount_min","table":"sample","expression":"amount >= 10","supported":true,"operator":">=",
         "left":{"kind":"column","table":"sample","column":"amount","type":"IntDataType"},
         "right":{"kind":"constant","value":"10","type":"NumericValue"}}
      ]},
      "tests":[
        {"id":"T1","expectedResult":false,
         "postgresValidation":{"phase":"data","actualResult":false,"sqlstate":"23503","constraintName":"sample_parent_id_fkey"},
         "coveredRequirementIds":["R_NEG"],"state":[],
         "data":[{"table":"sample","values":{"amount":"9"}}],"stateInsertCount":0,"dataInsertCount":1}
      ]})JSON";
    minimizer::Input input = minimizer::parse_input(minimizer::Json::parse(fixture));
    minimizer::Coverage coverage = minimizer::build_coverage(input);
    require(coverage.boundaries.empty(), "foreign-key rejection must not prove CHECK boundary coverage");
    require(coverage.unverified_boundary_tests.count("T1") == 1,
            "masked boundary candidate must be reported as unverified");
    minimizer::Json report = minimizer::minimize(input, coverage);
    require(report.at("unverifiedBoundaryTestIds").as_array().size() == 1,
            "report must expose the unverified candidate");
}

void test_unsupported_check() {
    const std::string fixture = R"JSON({
      "formatVersion":1,"snapshotSha256":"fixture-unsupported",
      "schema":{"checks":[
        {"id":"complex","table":"sample","expression":"x + 1 > 2","supported":false,
         "unsupportedReason":"CHECK is not a simple relational expression"}
      ]},
      "tests":[
        {"id":"T1","expectedResult":true,"coveredRequirementIds":["R1"],"state":[],"data":[],
         "stateInsertCount":0,"dataInsertCount":0}
      ]})JSON";
    minimizer::Json report = run(fixture);
    require(report.at("unsupportedChecks").as_array().size() == 1, "unsupported check must be reported");
}

void test_duplicate_id_rejected() {
    const std::string fixture = R"JSON({
      "formatVersion":1,"snapshotSha256":"fixture-duplicate","schema":{"checks":[]},
      "tests":[
        {"id":"T1","expectedResult":true,"coveredRequirementIds":["R1"],"state":[],"data":[],"stateInsertCount":0,"dataInsertCount":0},
        {"id":"T1","expectedResult":true,"coveredRequirementIds":["R1"],"state":[],"data":[],"stateInsertCount":0,"dataInsertCount":0}
      ]})JSON";
    bool failed = false;
    try {
        minimizer::Input input = minimizer::parse_input(minimizer::Json::parse(fixture));
        (void)minimizer::build_coverage(input);
    } catch (const std::runtime_error&) {
        failed = true;
    }
    require(failed, "duplicate test id must fail");
}

}  // namespace

int main() {
    try {
        test_boundary_preservation();
        test_null_and_bigint();
        test_foreign_key_failure_does_not_count_as_check_boundary();
        test_unsupported_check();
        test_duplicate_id_rejected();
        std::cout << "All minimizer tests passed\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "Test failure: " << error.what() << '\n';
        return 1;
    }
}
