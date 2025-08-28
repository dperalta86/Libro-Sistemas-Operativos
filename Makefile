name: Makefile CI

on:
  push:
    branches: [ "main" ]
  pull_request:
    branches: [ "main" ]

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v4
    - uses: actions/setup-node@v4
      with:
        node-version: '20'

    - name: Install system dependencies
      run: |
        sudo apt-get update
        sudo apt-get install -y pandoc texlive-xetex texlive-latex-extra texlive-fonts-recommended texlive-fonts-extra texlive-lang-spanish
        sudo apt-get install -y libnss3 libatk-bridge2.0-0 libxkbcommon0 libgtk-3-0 libasound2

    - name: Install Mermaid CLI
      run: npm install -g @mermaid-js/mermaid-cli@latest

    - name: Compile PDF with Makefile
      run: make

    - name: Upload artifact
      uses: actions/upload-artifact@v4
      with:
        name: book
        path: build/Introduccion_a_los_Sistemas_Operativos.pdf