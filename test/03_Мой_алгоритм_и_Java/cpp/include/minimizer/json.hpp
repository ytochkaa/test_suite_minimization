#pragma once

#include <map>
#include <string>
#include <variant>
#include <vector>

namespace minimizer {

class Json {
public:
    using Array = std::vector<Json>;
    using Object = std::map<std::string, Json>;
    using Number = long double;

    Json();
    Json(std::nullptr_t);
    Json(bool value);
    Json(Number value);
    Json(int value);
    Json(long long value);
    Json(std::string value);
    Json(const char* value);
    Json(Array value);
    Json(Object value);

    bool is_null() const;
    bool is_bool() const;
    bool is_number() const;
    bool is_string() const;
    bool is_array() const;
    bool is_object() const;

    bool as_bool() const;
    Number as_number() const;
    const std::string& as_string() const;
    const Array& as_array() const;
    const Object& as_object() const;
    Array& as_array();
    Object& as_object();

    const Json& at(const std::string& key) const;
    bool contains(const std::string& key) const;

    static Json parse(const std::string& text);
    std::string dump(int indent = 2) const;

private:
    using Storage = std::variant<std::nullptr_t, bool, Number, std::string, Array, Object>;
    Storage value_;
};

}  // namespace minimizer
