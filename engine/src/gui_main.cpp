// #include <QGuiApplication>
// #include <QQmlApplicationEngine>
// #include <QQmlContext>
// #include "Engine.h"

#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include "Engine.h"
#include "llama.h"

// Silent logger for llama.cpp
static void silent_logger(enum ggml_log_level level, const char *text, void *user_data)
{
    // Suppress llama.cpp logs
}

int main(int argc, char *argv[])
{
    // Set silent logger for llama.cpp
    llama_log_set(silent_logger, nullptr);

    QGuiApplication app(argc, argv);

    // Register Engine type with QML
    qmlRegisterType<Engine>("LocalLLM", 1, 0, "Engine");

    QQmlApplicationEngine engine;
    
    // Load main QML file
    const QUrl url(u"qrc:/LunarStudioUI/src/qml/Main.qml"_qs);
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreated,
        &app,
        [url](QObject *obj, const QUrl &objUrl) {
            if (!obj && url == objUrl)
                QCoreApplication::exit(-1);
        },
        Qt::QueuedConnection);
    
    engine.load(url);

    return app.exec();
}

// int main(int argc, char *argv[])
// {
//     QGuiApplication app(argc, argv);

//     // Register C++ class so QML can use Engine { }
//     qmlRegisterType<Engine>("LocalLLM", 1, 0, "Engine");

//     QQmlApplicationEngine engine;

//     // Correct QML entry file in your project
//     const QUrl url(u"qrc:/LunarStudioUI/src/qml/Main.qml"_qs);

//     QObject::connect(
//         &engine, &QQmlApplicationEngine::objectCreated,
//         &app,
//         [url](QObject *obj, const QUrl &objUrl)
//         {
//             if (!obj && url == objUrl)
//                 QCoreApplication::exit(-1);
//         },
//         Qt::QueuedConnection);
//     engine.addImportPath("qrc:/");
//     engine.setOutputWarningsToStandardError(true);

//     engine.load(url);

//     return app.exec();
// }
