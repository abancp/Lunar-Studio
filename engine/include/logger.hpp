#pragma once
#include <string>
#include <fstream>
#include <iostream>
#include <sstream>
#include <ctime>

// Enum to represent log levels
enum LogLevel {
    DEBUG,
    INFO,
    WARNING,
    ERROR,
    CRITICAL
};

class Logger {
public:
    // Constructor: opens log file in append mode
    explicit Logger(const std::string &filename);

    // Destructor: closes the log file
    ~Logger();

    // Logs a message with a given log level
    void log(LogLevel level, const std::string &message);

private:
    std::ofstream logFile; // File stream for the log file

    // Converts log level enum to string
    std::string levelToString(LogLevel level);
};
