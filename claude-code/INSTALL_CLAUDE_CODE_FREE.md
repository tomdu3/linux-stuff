# Setup Claude Code with OmniRoute (Free AI stack)

This guide is based on the instructions from the video: [Claude Code is now free](https://youtu.be/NJ0TQ-pyMDY)

---

## Step 1: Install Node.js
Download and install Node.js from the official website for your operating system (e.g., the Windows installer).

## Step 2: Install Omni Route
1. Go to Omni Route ([omniroute.online](https://omniroute.online/)) and click **Start for Free**.
2. Open your terminal (e.g., in VS Code) and paste the provided installation command:
   ```sh
   npm install -g omniroute
   ```
3. Once running on your localhost, open the local host link in your browser.
4. Log in using the default password: `CHANGE ME` (in all caps), and change it later.

### OmniRoute Environment Fix (Ubuntu/Linux)
If running `omniroute` gives you a `command not found` error after installing it globally, it happens because the directory where npm installs global executables is not in your system's `PATH` environment variable. Here's how to fix it on Ubuntu.

Check the actual node path:
```sh
npm config get prefix
```

We need to add the resulting path to your shell configuration file.

1. Open your `.bashrc` file (since you're using Ubuntu):
   ```bash
   nano ~/.bashrc
   ```
2. Add this line at the very end of the file:
   ```bash
   export PATH="$(npm config get prefix)/bin:$PATH"
   ```
3. Save and exit (`Ctrl+O`, `Enter`, then `Ctrl+X`).
4. Reload the configuration:
   ```bash
   source ~/.bashrc
   ```
5. Run `omniroute` again. It should now work.

---

## Step 3: Connect Free AI Providers
Inside Omni Route, navigate to **Providers**. Connect free providers to get free AI models (such as OpenRouter, KOAI, Anti-Gravity, and Nvidia NIM):

* **OpenRouter**: Search for Open Router, generate an API key from the Open Router website, paste it into Omni Route, and select **Import only free models**.
* **KOAI & Anti-Gravity**: Connect using your Google/Gmail account authorization.
* **Nvidia NIM**: Generate an API key from your Nvidia account, paste it into Omni Route, and import free models.

---

## Step 4: Create a Combo (Model Stack)
1. Go to the **Combo** section in Omni Route and create a new combo (e.g., named "Free Stack").
2. Select your preferred provider (e.g., Anti-Gravity) and arrange your desired free models using priority arrows (or add extra models from other connected providers like Nvidia NIM).
3. Set the strategy to **Round Robin** so it automatically switches to the next available model.
4. Test the combo, then generate and copy an API key for the combo.

---

## Step 5: Install Claude Code
1. Copy the Claude Code installation command for your operating system from the Claude Code website.
   * On Linux/macOS:
     ```sh
     curl -fsSL https://claude.ai/install.sh | bash
     ```
2. Paste and run the command in your terminal.
3. If `claude` is not recognized as a command, add the installation path (`.../bin`) to your system's Environment Variables (under Path).
4. Restart your terminal or VS Code.

---

## Step 6: Configure Claude Code to Use Omni Route
1. Ensure Omni Route is running locally in your terminal (`omniroute`).
2. Launch Claude Code with your custom Omni Route combo and API key by running the setup command with your combo name and API key.
3. Follow the initial prompts in the terminal (accept recommendations, trust the folder) to finish setting up, and you are ready to use Claude Code for free!
