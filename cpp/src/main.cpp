#include "minimizer/boundary.hpp"
#include "minimizer/json.hpp"
#include "minimizer/minimizer.hpp"
#include "minimizer/model.hpp"

#include <fstream>
#include <iostream>
#include <sstream>
#include <stdexcept>

int main(int argc, char** argv) {
    if (argc != 3) {
        std::cerr << "Usage: test_suite_minimization <input.json> <output.json>\n";
        return 2;
    }
    try {
        std::ifstream input_stream(argv[1], std::ios::binary);
        if (!input_stream) throw std::runtime_error("cannot open input file");
        std::ostringstream buffer;
        buffer << input_stream.rdbuf();

        minimizer::Json root = minimizer::Json::parse(buffer.str());
        minimizer::Input input = minimizer::parse_input(root);
        minimizer::Coverage coverage = minimizer::build_coverage(input);
        minimizer::Json report = minimizer::minimize(input, coverage);

        std::ofstream output_stream(argv[2], std::ios::binary);
        if (!output_stream) throw std::runtime_error("cannot open output file");
        output_stream << report.dump(2) << '\n';

        std::cout << "input=" << argv[1] << '\n';
        std::cout << "output=" << argv[2] << '\n';
        std::cout << "tests=" << input.tests.size() << '\n';
        std::cout << "requirements=" << coverage.requirements.size() << '\n';
        std::cout << "boundaries=" << coverage.boundaries.size() << '\n';
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "error: " << error.what() << '\n';
        return 1;
    }
}
