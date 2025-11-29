#include <string>
#include <sqlite3.h>
#include <iostream>
#include <vector>
#include <faiss/IndexFlat.h>
#include <faiss/index_io.h>
#include <faiss/IndexIVF.h>

std::string get_text_by_id(sqlite3 *db, int id)
{
    std::string query = "SELECT text FROM mapping WHERE id = ?;";
    sqlite3_stmt *stmt;
    std::string result = "[Not Found]";

    if (sqlite3_prepare_v2(db, query.c_str(), -1, &stmt, nullptr) == SQLITE_OK)
    {
        sqlite3_bind_int(stmt, 1, id);
        if (sqlite3_step(stmt) == SQLITE_ROW)
        {
            const unsigned char *text = sqlite3_column_text(stmt, 0);
            if (text)
                result = reinterpret_cast<const char *>(text);
        }
    }
    sqlite3_finalize(stmt);
    return result;
}

std::vector<std::string> search(std::vector<float> query_emb, std::string db_path, std::string index_path)
{
    faiss::Index *index = faiss ::read_index(index_path.c_str());
    if (!index)
    {
        std::cerr << "Index can't load!" << std::endl;
        exit(1);
    }

    sqlite3 *db;
    if (sqlite3_open(db_path.c_str(), &db) != SQLITE_OK)
    {
        std::cerr << "Error loading while open sqlite_db " << sqlite3_errmsg(db) << std::endl;
        exit(1);
    }

    faiss::IndexIVF *ivf = dynamic_cast<faiss::IndexIVF *>(index);
    if (ivf)
        ivf->nprobe = 10;

    int top_k = 5;
    std::vector<std::string> result;
    std::vector<faiss::idx_t> I(top_k);
    std::vector<float> D(top_k);
    index->search(1, query_emb.data(), top_k, D.data(), I.data());

    for (int i = 0; i < top_k; i++)
    {
        if (I[i] < 0)
            continue;
        std::string text = get_text_by_id(db, I[i]);
        std::cout << "[" << i + 1 << "] " << text << "  (dist=" << D[i] << ")\n";
        result.push_back(text);
    }
    delete index;
    return result;
}