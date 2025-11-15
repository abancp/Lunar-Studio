# LunarStudio – Lightweight Local AI Desktop App (C++ + Qt + llama.cpp)

LunarStudio is a fast, privacy‑focused offline AI assistant built using **C++**, **Qt/QML**, **FAISS**, **SQLite**, and **llama.cpp**.
It performs vector search, embedding generation, and LLM inference fully offline inside your system.

---

## 🚀 Features

- Fast local inference using GGUF models  
- Semantic search powered by FAISS  
- Sentence embeddings with MiniLM  
- Local database storage using SQLite  
- 100% offline & private  
- Lightweight compared to Electron or web view frameworks  

---

## 📂 Project Structure

project/
├── CMakeLists.txt
├── src/
├── include/
├── models/
│   ├── all-MiniLM-L6-v2.F16.gguf
│   ├── qwen2.5-0.5b-instruct-q8_0.gguf
├── ic/
├── build/
└── README.md

---

## 📥 Download Required Models

Before running LunarStudio, download the following models into the **models** folder.

### 1. All-MiniLM-L6-v2 (Embeddings Model)

cd models/
wget https://huggingface.co/leliuga/all-MiniLM-L6-v2-GGUF/resolve/main/all-MiniLM-L6-v2.F16.gguf

### 2. Qwen2.5 0.5B Instruct (Main LLM)

cd models/
wget https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q8_0.gguf

---

## 🔧 Building the Project

### Dependencies (example for Arch Linux)

sudo pacman -S qt6-base qt6-declarative qt6-tools cmake make gcc faiss sqlite openblas lapack nlohmann-json

### Build Steps

cd lunar-studio
mkdir build && cd build
cmake ..
make -j$(nproc)

---

## ▶️ Running

### CLI:
./localGPT


---

## 🧠 How It Works

1. Embeddings generated using MiniLM  
2. FAISS vector search  
3. Qwen2.5 LLM generates response  

---

## 🛠 Development

 (C++): src/*.cpp, include/*.hpp  

---

## 🙌 Contributing

PRs and issues are welcome!

---

