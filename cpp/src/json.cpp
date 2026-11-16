#include "minimizer/json.hpp"

#include <cctype>
#include <cmath>
#include <iomanip>
#include <sstream>
#include <stdexcept>

namespace minimizer {
namespace {

class Parser {
public:
    explicit Parser(const std::string& text) : text_(text) {}

    Json parse() {
        skip_space();
        Json value = parse_value();
        skip_space();
        if (position_ != text_.size()) {
            fail("unexpected trailing characters");
        }
        return value;
    }

private:
    const std::string& text_;
    std::size_t position_ = 0;

    [[noreturn]] void fail(const std::string& message) const {
        throw std::runtime_error("JSON parse error at byte " + std::to_string(position_) + ": " + message);
    }

    void skip_space() {
        while (position_ < text_.size() && std::isspace(static_cast<unsigned char>(text_[position_]))) {
            ++position_;
        }
    }

    char peek() const {
        if (position_ >= text_.size()) {
            throw std::runtime_error("JSON parse error: unexpected end of input");
        }
        return text_[position_];
    }

    bool consume(char expected) {
        if (position_ < text_.size() && text_[position_] == expected) {
            ++position_;
            return true;
        }
        return false;
    }

    void expect_literal(const char* literal) {
        while (*literal != '\0') {
            if (position_ >= text_.size() || text_[position_] != *literal) {
                fail("invalid literal");
            }
            ++position_;
            ++literal;
        }
    }

    Json parse_value() {
        skip_space();
        switch (peek()) {
            case 'n': expect_literal("null"); return Json(nullptr);
            case 't': expect_literal("true"); return Json(true);
            case 'f': expect_literal("false"); return Json(false);
            case '"': return Json(parse_string());
            case '[': return parse_array();
            case '{': return parse_object();
            default:
                if (peek() == '-' || std::isdigit(static_cast<unsigned char>(peek()))) {
                    return parse_number();
                }
                fail("unexpected character");
        }
    }

    std::string parse_string() {
        if (!consume('"')) {
            fail("expected string");
        }
        std::string result;
        while (position_ < text_.size()) {
            char character = text_[position_++];
            if (character == '"') {
                return result;
            }
            if (character != '\\') {
                result.push_back(character);
                continue;
            }
            if (position_ >= text_.size()) {
                fail("unfinished escape sequence");
            }
            char escaped = text_[position_++];
            switch (escaped) {
                case '"': result.push_back('"'); break;
                case '\\': result.push_back('\\'); break;
                case '/': result.push_back('/'); break;
                case 'b': result.push_back('\b'); break;
                case 'f': result.push_back('\f'); break;
                case 'n': result.push_back('\n'); break;
                case 'r': result.push_back('\r'); break;
                case 't': result.push_back('\t'); break;
                case 'u': parse_unicode(result); break;
                default: fail("invalid escape sequence");
            }
        }
        fail("unterminated string");
    }

    void parse_unicode(std::string& output) {
        if (position_ + 4 > text_.size()) {
            fail("unfinished unicode escape");
        }
        unsigned value = 0;
        for (int index = 0; index < 4; ++index) {
            char character = text_[position_++];
            value <<= 4;
            if (character >= '0' && character <= '9') value += character - '0';
            else if (character >= 'a' && character <= 'f') value += character - 'a' + 10;
            else if (character >= 'A' && character <= 'F') value += character - 'A' + 10;
            else fail("invalid unicode escape");
        }
        if (value <= 0x7f) {
            output.push_back(static_cast<char>(value));
        } else if (value <= 0x7ff) {
            output.push_back(static_cast<char>(0xc0 | (value >> 6)));
            output.push_back(static_cast<char>(0x80 | (value & 0x3f)));
        } else {
            output.push_back(static_cast<char>(0xe0 | (value >> 12)));
            output.push_back(static_cast<char>(0x80 | ((value >> 6) & 0x3f)));
            output.push_back(static_cast<char>(0x80 | (value & 0x3f)));
        }
    }

    Json parse_number() {
        std::size_t start = position_;
        consume('-');
        if (consume('0')) {
            // zero is complete unless a fractional/exponent part follows
        } else {
            if (!std::isdigit(static_cast<unsigned char>(peek()))) fail("invalid number");
            while (position_ < text_.size() && std::isdigit(static_cast<unsigned char>(text_[position_]))) ++position_;
        }
        if (consume('.')) {
            if (position_ >= text_.size() || !std::isdigit(static_cast<unsigned char>(text_[position_]))) fail("invalid fraction");
            while (position_ < text_.size() && std::isdigit(static_cast<unsigned char>(text_[position_]))) ++position_;
        }
        if (position_ < text_.size() && (text_[position_] == 'e' || text_[position_] == 'E')) {
            ++position_;
            if (position_ < text_.size() && (text_[position_] == '+' || text_[position_] == '-')) ++position_;
            if (position_ >= text_.size() || !std::isdigit(static_cast<unsigned char>(text_[position_]))) fail("invalid exponent");
            while (position_ < text_.size() && std::isdigit(static_cast<unsigned char>(text_[position_]))) ++position_;
        }
        return Json(std::stold(text_.substr(start, position_ - start)));
    }

    Json parse_array() {
        consume('[');
        Json::Array result;
        skip_space();
        if (consume(']')) return Json(std::move(result));
        while (true) {
            result.push_back(parse_value());
            skip_space();
            if (consume(']')) return Json(std::move(result));
            if (!consume(',')) fail("expected ',' in array");
        }
    }

    Json parse_object() {
        consume('{');
        Json::Object result;
        skip_space();
        if (consume('}')) return Json(std::move(result));
        while (true) {
            skip_space();
            std::string key = parse_string();
            skip_space();
            if (!consume(':')) fail("expected ':' in object");
            result.emplace(std::move(key), parse_value());
            skip_space();
            if (consume('}')) return Json(std::move(result));
            if (!consume(',')) fail("expected ',' in object");
        }
    }
};

std::string escape(const std::string& value) {
    std::ostringstream output;
    output << '"';
    for (unsigned char character : value) {
        switch (character) {
            case '"': output << "\\\""; break;
            case '\\': output << "\\\\"; break;
            case '\b': output << "\\b"; break;
            case '\f': output << "\\f"; break;
            case '\n': output << "\\n"; break;
            case '\r': output << "\\r"; break;
            case '\t': output << "\\t"; break;
            default:
                if (character < 0x20) {
                    output << "\\u" << std::hex << std::setw(4) << std::setfill('0') << static_cast<int>(character);
                } else {
                    output << static_cast<char>(character);
                }
        }
    }
    output << '"';
    return output.str();
}

void dump(const Json& value, std::ostringstream& output, int indent, int depth) {
    const std::string padding(static_cast<std::size_t>(depth * indent), ' ');
    const std::string child_padding(static_cast<std::size_t>((depth + 1) * indent), ' ');
    if (value.is_null()) output << "null";
    else if (value.is_bool()) output << (value.as_bool() ? "true" : "false");
    else if (value.is_number()) {
        long double number = value.as_number();
        if (std::floor(number) == number) output << std::fixed << std::setprecision(0) << number;
        else output << std::setprecision(18) << number;
    } else if (value.is_string()) output << escape(value.as_string());
    else if (value.is_array()) {
        output << '[';
        const auto& array = value.as_array();
        for (std::size_t index = 0; index < array.size(); ++index) {
            if (index > 0) output << ',';
            if (indent > 0) output << '\n' << child_padding;
            dump(array[index], output, indent, depth + 1);
        }
        if (!array.empty() && indent > 0) output << '\n' << padding;
        output << ']';
    } else {
        output << '{';
        std::size_t index = 0;
        for (const auto& entry : value.as_object()) {
            if (index++ > 0) output << ',';
            if (indent > 0) output << '\n' << child_padding;
            output << escape(entry.first) << (indent > 0 ? ": " : ":");
            dump(entry.second, output, indent, depth + 1);
        }
        if (!value.as_object().empty() && indent > 0) output << '\n' << padding;
        output << '}';
    }
}

}  // namespace

Json::Json() : value_(nullptr) {}
Json::Json(std::nullptr_t) : value_(nullptr) {}
Json::Json(bool value) : value_(value) {}
Json::Json(Number value) : value_(value) {}
Json::Json(int value) : value_(static_cast<Number>(value)) {}
Json::Json(long long value) : value_(static_cast<Number>(value)) {}
Json::Json(std::string value) : value_(std::move(value)) {}
Json::Json(const char* value) : value_(std::string(value)) {}
Json::Json(Array value) : value_(std::move(value)) {}
Json::Json(Object value) : value_(std::move(value)) {}

bool Json::is_null() const { return std::holds_alternative<std::nullptr_t>(value_); }
bool Json::is_bool() const { return std::holds_alternative<bool>(value_); }
bool Json::is_number() const { return std::holds_alternative<Number>(value_); }
bool Json::is_string() const { return std::holds_alternative<std::string>(value_); }
bool Json::is_array() const { return std::holds_alternative<Array>(value_); }
bool Json::is_object() const { return std::holds_alternative<Object>(value_); }
bool Json::as_bool() const { return std::get<bool>(value_); }
Json::Number Json::as_number() const { return std::get<Number>(value_); }
const std::string& Json::as_string() const { return std::get<std::string>(value_); }
const Json::Array& Json::as_array() const { return std::get<Array>(value_); }
const Json::Object& Json::as_object() const { return std::get<Object>(value_); }
Json::Array& Json::as_array() { return std::get<Array>(value_); }
Json::Object& Json::as_object() { return std::get<Object>(value_); }
const Json& Json::at(const std::string& key) const { return as_object().at(key); }
bool Json::contains(const std::string& key) const { return is_object() && as_object().count(key) != 0; }
Json Json::parse(const std::string& text) { return Parser(text).parse(); }
std::string Json::dump(int indent) const { std::ostringstream output; ::minimizer::dump(*this, output, indent, 0); return output.str(); }

}  // namespace minimizer
