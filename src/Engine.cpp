#include "Engine.h"
#include "run_llm.hpp"
#include "embed.hpp"
#include "search.hpp"
#include "extract_search_query.hpp"
#include <QMutexLocker>
#include <QDebug>
#include <iostream>

// Model paths - adjust these to your actual paths
static const std::string EMBED_MODEL_PATH = "models/all-MiniLM-L6-v2.F16.gguf";
static const std::string LLM_MODEL_PATH = "models/Qwen3-0.6B-Q8_0.gguf";
static const std::string DB_PATH = "ic/cs/mapping.db";
static const std::string INDEX_PATH = "ic/cs/cpp_index_ivf.index";

// WorkerThread Implementation
WorkerThread::WorkerThread(QObject *parent)
    : QThread(parent)
    , m_stopRequested(false)
{
}

void WorkerThread::setPrompt(const QString &prompt)
{
    QMutexLocker locker(&m_mutex);
    m_prompt = prompt;
}

void WorkerThread::stop()
{
    m_stopRequested = true;
}

void WorkerThread::run()
{
    m_stopRequested = false;
    QString prompt;
    
    {
        QMutexLocker locker(&m_mutex);
        prompt = m_prompt;
    }

    if (prompt.isEmpty())
    {
        emit finished();
        return;
    }

    std::string query = prompt.toStdString();

    // Token callback that emits to Qt
    auto tokenCallback = [this](const std::string &token) {
        if (!m_stopRequested)
        {
            // Emit signal that crosses thread boundary safely
            emit tokenReady(QString::fromStdString(token));
        }
    };

    try
    {
        // First pass - check if search is needed
        qDebug() << "Starting LLM generation (search detection phase)...";
        std::string res = run_model(query, LLM_MODEL_PATH.c_str(), true, {}, tokenCallback);
        
        qDebug() << "First pass complete. Response:" << QString::fromStdString(res);

        // Check if model requested a search
        if (res.find("search(") != std::string::npos && !m_stopRequested)
        {
            qDebug() << "Search detected in response!";
            
            // Extract search query
            std::string search_query = extract_search_query(res);
            qDebug() << "Extracted search query:" << QString::fromStdString(search_query);
            
            if (!search_query.empty())
            {
                // Perform embedding
                qDebug() << "Generating embedding...";
                std::vector<float> query_embed = embed(search_query, EMBED_MODEL_PATH.c_str());
                qDebug() << "Embedding generated, size:" << query_embed.size();
                
                // Perform search
                qDebug() << "Searching database...";
                std::vector<std::string> results = search(query_embed, DB_PATH, INDEX_PATH);
                qDebug() << "Found" << results.size() << "results";

                // Debug: Print search results
                for (size_t i = 0; i < results.size(); i++)
                {
                    qDebug() << "Result" << i << ":" << QString::fromStdString(results[i]).left(100);
                }

                // Second pass - answer with search results
                if (!m_stopRequested && !results.empty())
                {
                    qDebug() << "Starting LLM generation (answer phase)...";
                    res = run_model(query, LLM_MODEL_PATH.c_str(), false, results, tokenCallback);
                    qDebug() << "Answer phase complete";
                }
            }
            else
            {
                qDebug() << "Failed to extract search query";
            }
        }
        else
        {
            qDebug() << "No search needed, response is final";
        }
    }
    catch (const std::exception &e)
    {
        qDebug() << "Error in WorkerThread:" << e.what();
        emit tokenReady(QString("\n\nError: %1").arg(e.what()));
    }
    catch (...)
    {
        qDebug() << "Unknown error in WorkerThread";
        emit tokenReady(QString("\n\nUnknown error occurred"));
    }

    emit finished();
}

// Engine Implementation
Engine::Engine(QObject *parent)
    : QObject(parent)
    , m_workerThread(nullptr)
    , m_isGenerating(false)
{
    qDebug() << "Engine created";
}

Engine::~Engine()
{
    if (m_workerThread && m_workerThread->isRunning())
    {
        qDebug() << "Stopping worker thread...";
        m_workerThread->stop();
        m_workerThread->wait(5000); // Wait max 5 seconds
        if (m_workerThread->isRunning())
        {
            m_workerThread->terminate();
            m_workerThread->wait();
        }
    }
    
    if (m_workerThread)
    {
        delete m_workerThread;
    }
}

void Engine::ask(const QString &prompt)
{
    if (m_isGenerating)
    {
        qDebug() << "Already generating, ignoring request";
        return; // Already generating
    }

    qDebug() << "Ask called with prompt:" << prompt;

    // Clean up old thread if exists
    if (m_workerThread)
    {
        if (m_workerThread->isRunning())
        {
            m_workerThread->stop();
            m_workerThread->wait();
        }
        delete m_workerThread;
    }

    // Create new worker thread
    m_workerThread = new WorkerThread(this);
    
    // Connect worker signals
    connect(m_workerThread, &WorkerThread::tokenReady,
            this, &Engine::onTokenReceived, Qt::QueuedConnection);
    connect(m_workerThread, &WorkerThread::finished,
            this, &Engine::onGenerationComplete, Qt::QueuedConnection);

    m_isGenerating = true;
    emit isGeneratingChanged();

    m_workerThread->setPrompt(prompt);
    m_workerThread->start();
    
    qDebug() << "Worker thread started";
}

void Engine::onTokenReceived(const QString &token)
{
    // This runs in the main thread (Qt automatically handles the thread switch)
    emit tokenGenerated(token);
}

void Engine::onGenerationComplete()
{
    qDebug() << "Generation complete";
    m_isGenerating = false;
    emit isGeneratingChanged();
    emit generationFinished();
}

bool Engine::isGenerating() const
{
    return m_isGenerating;
}