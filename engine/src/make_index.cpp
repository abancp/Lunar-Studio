#include <iostream>
#include <fstream>
#include <vector>
#include <string>
#include <cmath>
#include <filesystem>
#include <nlohmann/json.hpp>
#include <faiss/IndexFlat.h>
#include <faiss/IndexIVFFlat.h>
#include <faiss/index_io.h>
#include "embed.hpp"

using json = nlohmann::json;

bool file_exists(const std::string &path)
{
    std::ifstream f(path);
    return f.good();
}
bool has_extension(const std::string &path, const std::unordered_set<std::string> &exts)
{
    size_t pos = path.find_last_of('.');
    if (pos == std::string::npos)
        return false;
    std::string ext = path.substr(pos + 1);
    return exts.count(ext) > 0;
}

void print_help()
{
    std::cout << "Usage:\n"
              << "  lunarstudio_indexer --model <path> --input <path> "
              << "--out-index <path> --out-json <path>\n\n"

              << "Options:\n"
              << "  --model <path>      Path to GGUF model file (.gguf)\n"
              << "  --input <path>      Path to input JSONL file (.jsonl)\n"
              << "  --out-index <path>  Output IVF index file (.index)\n"
              << "  --out-json <path>   Output mapping file (.json)\n"
              << "  --help              Show this help message\n\n";
}

int main(int argc, char *argv[])
{
    std::string model_path;
    std::string input_path;
    std::string output_index;
    std::string output_json;

    for (int i = 1; i < argc; i++)
    {
        std::string arg = argv[i];

        if (arg == "--help")
        {
            print_help();
            return 0;
        }
        else if (arg == "--model" && i + 1 < argc)
        {
            model_path = argv[++i];
        }
        else if (arg == "--input" && i + 1 < argc)
        {
            input_path = argv[++i];
        }
        else if (arg == "--out-index" && i + 1 < argc)
        {
            output_index = argv[++i];
        }
        else if (arg == "--out-json" && i + 1 < argc)
        {
            output_json = argv[++i];
        }
    }

    if (model_path.empty() || input_path.empty() || output_index.empty() || output_json.empty())
    {
        std::cerr << "Error: Missing required arguments.\n\n";
        print_help();
        return 1;
    }

    if (!file_exists(model_path))
    {
        std::cerr << "Error: Model file not found: " << model_path << "\n";
        return 1;
    }
    if (!has_extension(model_path, {"gguf"}))
    {
        std::cerr << "Error: Model file must be .gguf\n";
        return 1;
    }

    if (!file_exists(input_path))
    {
        std::cerr << "Error: Input JSONL not found: " << input_path << "\n";
        return 1;
    }
    if (!has_extension(input_path, {"jsonl"}))
    {
        std::cerr << "Error: Input file must be .jsonl\n";
        return 1;
    }

    if (!has_extension(output_index, {"index"}))
    {
        std::cerr << "Error: Output index must be .index\n";
        return 1;
    }

    if (!has_extension(output_json, {"json"}))
    {
        std::cerr << "Error: Output mapping must be .json\n";
        return 1;
    }

    std::cout << "Model:       " << model_path << "\n";
    std::cout << "Input:       " << input_path << "\n";
    std::cout << "Output IDX:  " << output_index << "\n";
    std::cout << "Output JSON: " << output_json << "\n\n";

    std::cout << "All inputs validated. Starting indexing...\n";
    std::ifstream infile(input_path);
    if (!infile.is_open())
    {
        std::cerr << "❌ Cannot open file: " << input_path << std::endl;
        return 1;
    }

    std::vector<std::string> texts;
    std::vector<std::vector<float>> embeddings;

    std::string line;
    size_t line_count = 0;

    while (std::getline(infile, line))
    {
        if (line.empty())
            continue;
        json j = json::parse(line);

        std::string text = j["text"];
        std::vector<float> emb = embed(text, model_path.c_str());
        for (int i = 0; i < emb.size(); i++)
        {
            std::cout << emb[i] << " ";
        }
        embeddings.push_back(emb);
        texts.push_back(text);

        if (++line_count % 50 == 0)
            std::cout << "Processed " << line_count << " texts...\n";
    }

    infile.close();
    size_t n = embeddings.size();
    size_t dim = embeddings[0].size();

    std::cout << "✅ Total embeddings: " << n << ", Dimension: " << dim << std::endl;

    // Convert embeddings to float* for FAISS
    std::vector<float> flat;
    flat.reserve(n * dim);
    for (const auto &e : embeddings)
    {
        flat.insert(flat.end(), e.begin(), e.end());
    }

    size_t nlist = static_cast<size_t>(std::sqrt(n));
    if (nlist < 1)
        nlist = 1;

    std::cout << "Building IVF index with nlist = " << nlist << " ..." << std::endl;

    faiss::IndexFlatL2 quantizer(dim);
    faiss::IndexIVFFlat index(&quantizer, dim, nlist);

    std::cout << "Training index..." << std::endl;
    index.train(n, flat.data());

    std::cout << "Adding embeddings..." << std::endl;
    index.add(n, flat.data());
    faiss::write_index(&index, output_index.c_str());
    std::cout << "✅ Saved IVF index to: " << output_index << std::endl;

    std::ofstream map_out(output_json);
    json text_json = texts;
    map_out << text_json.dump(2);
    map_out.close();
    std::cout << "✅ Saved mapping to: " << output_json << std::endl;

    return 0;
}
