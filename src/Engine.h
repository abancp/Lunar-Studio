#ifndef ENGINE_H
#define ENGINE_H

#include <QObject>
#include <QString>
#include <QThread>
#include <QMutex>
#include <atomic>

class WorkerThread;

class Engine : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool isGenerating READ isGenerating NOTIFY isGeneratingChanged)

public:
    explicit Engine(QObject *parent = nullptr);
    ~Engine();

    Q_INVOKABLE void ask(const QString &prompt);
    bool isGenerating() const;

signals:
    void tokenGenerated(const QString &token);
    void generationFinished();
    void isGeneratingChanged();
    void startGeneration(const QString &prompt);

private slots:
    void onTokenReceived(const QString &token);
    void onGenerationComplete();

private:
    WorkerThread *m_workerThread;
    std::atomic<bool> m_isGenerating;
};

// Worker thread class for running model inference
class WorkerThread : public QThread
{
    Q_OBJECT

public:
    explicit WorkerThread(QObject *parent = nullptr);
    void setPrompt(const QString &prompt);
    void stop();

signals:
    void tokenReady(const QString &token);
    void finished();

protected:
    void run() override;

private:
    QString m_prompt;
    QMutex m_mutex;
    std::atomic<bool> m_stopRequested;
};

#endif // ENGINE_H