#pragma once

#include "minimizer/model.hpp"

#include <map>
#include <set>
#include <string>
#include <vector>

namespace minimizer {

struct Coverage {
    std::map<std::string, std::set<std::string>> by_test;
    std::set<std::string> requirements;
    std::set<std::string> boundaries;
    std::vector<std::string> unsupported_checks;
};

Coverage build_coverage(const Input& input);

}  // namespace minimizer
