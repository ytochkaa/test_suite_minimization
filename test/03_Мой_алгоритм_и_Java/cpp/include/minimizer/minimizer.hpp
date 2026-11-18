#pragma once

#include "minimizer/boundary.hpp"
#include "minimizer/json.hpp"
#include "minimizer/model.hpp"

namespace minimizer {

Json minimize(const Input& input, const Coverage& coverage);

}  // namespace minimizer
