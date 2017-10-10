# Project Lovelace

**Prerequisites**

Install nodejs and iverilog and clone this repository

**Download Dependencies**

Run `npm install` (to install dependencies) and `npm run build` (to compile the verilog) in project root directory

**Start server**

Run `node index.js` in project root directory

**Use Program**

Nagigate to `localhost:3000` in your browser of choice

**How do I work on the iverilog code?**

You don't need the server to be running in order to work on the verilog code. Just edit `index.v` and compile it using either `npm run build` (requires node) or `iverilog index.v` (doesn't require node). You can then run the resulting file (`a.out`), once again not requiring the server to be running. You'll be able to see stdout and write to stdin from within your command prompt or terminal. 
