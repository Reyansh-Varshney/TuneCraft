// NAME: SpotifyDownloader
// AUTHOR: Claude (original) / Gemini (enhanced)
// DESCRIPTION: Downloads playlists or individual tracks using spotDL with a user-specified path.

(function SpotifyDownloader() {

    // --- Initial Setup and Spicetify Wait ---

    // Wait for Spicetify to be fully loaded
    if (!Spicetify) {
        setTimeout(SpotifyDownloader, 300);
        return;
    }

    // --- Utility Functions ---

    /**
     * Sanitizes a string for use as a folder or file name, removing invalid characters.
     * @param {string} name - The original name to sanitize.
     * @returns {string} The sanitized name.
     */
    function sanitizeName(name) {
        // Replaces characters that are illegal in Windows/Unix filenames with a hyphen
        return name.replace(/[/\\?%*:|"<>]/g, '-').trim();
    }

    /**
     * Executes a shell command by sending a request to a local server.
     * IMPORTANT: This requires a separate local server (e.g., in Python, Node.js)
     * listening on http://localhost:8765/execute that can securely execute commands.
     * @param {string} command - The command string to execute.
     * @returns {Promise<Object>} A promise that resolves with the server's response.
     * @throws {Error} If the fetch request fails or the server returns an error.
     */
    async function executeCommand(command) {
        try {
            const response = await fetch('http://localhost:8765/execute', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({ command }),
            });

            if (!response.ok) {
                const errorData = await response.json();
                throw new Error(`Server responded with status ${response.status}: ${errorData.message || response.statusText}`);
            }

            return await response.json();
        } catch (error) {
            console.error('Failed to execute command:', error);
            Spicetify.showNotification("Error: Local server unreachable or command failed. Check console.");
            throw error;
        }
    }

    // --- Path Prompt Modal ---

    // Keys for localStorage
    const LAST_DOWNLOAD_PATH_KEY = 'spotdlLastDownloadPath';

    /**
     * Loads the last used download path from localStorage.
     * @returns {string} The last used path, or an empty string if not found.
     */
    function loadLastDownloadPath() {
        try {
            return localStorage.getItem(LAST_DOWNLOAD_PATH_KEY) || '';
        } catch (e) {
            console.error("Error loading last download path from localStorage:", e);
            return '';
        }
    }

    /**
     * Saves the provided path to localStorage as the last used download path.
     * @param {string} path - The path to save.
     */
    function saveLastDownloadPath(path) {
        try {
            localStorage.setItem(LAST_DOWNLOAD_PATH_KEY, path);
        } catch (e) {
            console.error("Error saving last download path to localStorage:", e);
        }
    }

    /**
     * Creates and injects the HTML for the path prompt modal into the document body.
     */
    function createPathPromptModal() {
        const modalHtml = `
            <div id="spotdl-path-prompt-modal" style="
                position: fixed;
                top: 50%;
                left: 50%;
                transform: translate(-50%, -50%);
                background-color: var(--spice-main-alt); /* Spotify background color */
                border-radius: 8px;
                padding: 20px;
                box-shadow: 0 4px 20px rgba(0, 0, 0, 0.5);
                z-index: 10000;
                display: none; /* Hidden by default */
                width: 90%;
                max-width: 450px;
                color: var(--spice-text); /* Spotify text color */
                font-family: 'Inter', sans-serif; /* Use Inter font for consistency */
            ">
                <h2 style="margin-top: 0; color: var(--spice-text); font-size: 1.4em; text-align: center;">Download Location</h2>
                <div style="margin-bottom: 15px;">
                    <label for="spotdl-download-path-input" style="display: block; margin-bottom: 5px; font-weight: bold;">Path:</label>
                    <input type="text" id="spotdl-download-path-input" placeholder="e.g., C:/Music/Spotify Downloads" style="
                        width: calc(100% - 16px); /* Adjust for padding */
                        padding: 10px;
                        border: 1px solid var(--spice-secondary);
                        border-radius: 6px;
                        background-color: var(--spice-card);
                        color: var(--spice-text);
                        box-sizing: border-box; /* Include padding in width */
                    ">
                    <small style="color: var(--spice-subtext); display: block; margin-top: 5px;">Leave empty to use spotDL's default download location.</small>
                </div>
                <div style="display: flex; justify-content: flex-end; gap: 10px;">
                    <button id="spotdl-path-cancel-button" style="
                        background-color: var(--spice-secondary);
                        color: var(--spice-text);
                        border: none;
                        padding: 10px 20px;
                        border-radius: 20px; /* More rounded */
                        cursor: pointer;
                        font-weight: bold;
                        transition: background-color 0.2s ease;
                    " onmouseover="this.style.backgroundColor='var(--spice-secondary-hover)'" onmouseout="this.style.backgroundColor='var(--spice-secondary)'">Cancel</button>
                    <button id="spotdl-path-confirm-button" style="
                        background-color: var(--spice-button);
                        color: var(--spice-text-active);
                        border: none;
                        padding: 10px 20px;
                        border-radius: 20px; /* More rounded */
                        cursor: pointer;
                        font-weight: bold;
                        transition: background-color 0.2s ease;
                    " onmouseover="this.style.backgroundColor='var(--spice-button-hover)'" onmouseout="this.style.backgroundColor='var(--spice-button)'">Download</button>
                </div>
            </div>
            <div id="spotdl-path-prompt-overlay" style="
                position: fixed;
                top: 0;
                left: 0;
                width: 100%;
                height: 100%;
                background-color: rgba(0, 0, 0, 0.7);
                z-index: 9999;
                display: none; /* Hidden by default */
            "></div>
        `;
        // Only append if not already present
        if (!document.getElementById('spotdl-path-prompt-modal')) {
            document.body.insertAdjacentHTML('beforeend', modalHtml);
        }
    }

    /**
     * Shows the path prompt modal and returns a Promise that resolves with the user's input path or null if canceled.
     * @returns {Promise<string|null>} A promise resolving with the path or null.
     */
    function showPathPromptModal() {
        return new Promise(resolve => {
            const modal = document.getElementById('spotdl-path-prompt-modal');
            const overlay = document.getElementById('spotdl-path-prompt-overlay');
            const pathInput = document.getElementById('spotdl-download-path-input');
            const confirmButton = document.getElementById('spotdl-path-confirm-button');
            const cancelButton = document.getElementById('spotdl-path-cancel-button');

            if (!modal || !overlay || !pathInput || !confirmButton || !cancelButton) {
                console.error("spotDL Path Prompt Modal elements not found.");
                resolve(null); // Resolve with null if elements are missing
                return;
            }

            // Populate with last used path
            pathInput.value = loadLastDownloadPath();

            // Display the modal
            modal.style.display = 'block';
            overlay.style.display = 'block';

            // Ensure previous listeners are removed to prevent multiple resolutions
            const cleanUp = () => {
                confirmButton.onclick = null;
                cancelButton.onclick = null;
                overlay.onclick = null;
                modal.style.display = 'none';
                overlay.style.display = 'none';
            };

            confirmButton.onclick = () => {
                const path = pathInput.value.trim();
                cleanUp();
                resolve(path);
            };

            cancelButton.onclick = () => {
                cleanUp();
                resolve(null); // Resolve with null on cancel
            };

            overlay.onclick = () => {
                cleanUp();
                resolve(null); // Resolve with null if clicking outside
            };

            pathInput.focus(); // Focus on the input field
        });
    }

    // --- Download Logic ---

    /**
     * Initiates the download of the current Spotify content (playlist or track) using spotDL.
     */
    async function downloadSpotifyContent() {
        try {
            const uri = Spicetify.Platform.History.location.pathname;
            let spotifyUrl = '';
            let contentName = '';

            // Determine if it's a playlist or a track page
            if (uri.includes('/playlist/')) {
                const playlistId = uri.split('/').pop();
                spotifyUrl = `https://open.spotify.com/playlist/${playlistId}`;
                const playlistNameElement = document.querySelector('h1[dir="auto"]');
                contentName = playlistNameElement ? playlistNameElement.textContent : 'Unknown_Playlist';
            } else if (uri.includes('/track/')) {
                const trackId = uri.split('/').pop();
                spotifyUrl = `https://open.spotify.com/track/${trackId}`;
                const trackNameElement = document.querySelector('.main-trackInfo-name');
                contentName = trackNameElement ? trackNameElement.textContent : 'Unknown_Track';
            } else {
                console.log('Not a playlist or track page');
                Spicetify.showNotification("Error: Navigate to a playlist or track page to download.");
                return;
            }

            const sanitizedName = sanitizeName(contentName);
            console.log('Content Name:', contentName);
            console.log('Spotify URL:', spotifyUrl);

            // Show the path prompt modal
            const chosenPath = await showPathPromptModal();

            if (chosenPath === null) {
                Spicetify.showNotification("Download cancelled by user.");
                return; // User cancelled the download
            }

            // Save the chosen path for next time
            saveLastDownloadPath(chosenPath);

            // Construct the spotDL command
            let spotdlCommand = `spotdl "${spotifyUrl}"`;

            if (chosenPath) {
                // If a path is provided, use --output-directory
                // spotDL will create a subfolder with the sanitized content name inside this directory
                spotdlCommand += ` --output-directory "${chosenPath}"`;
            } else {
                // If no path is provided (empty string), use --output to ensure a folder
                // is created in spotDL's default output location
                spotdlCommand += ` --output "${sanitizedName}"`;
            }

            console.log('Executing command:', spotdlCommand);
            Spicetify.showNotification(`Initiating download for "${contentName}" to "${chosenPath || 'spotDL default location'}"...`);

            try {
                // Execute the spotDL command via the local server
                await executeCommand(spotdlCommand);
                Spicetify.showNotification(`"${contentName}" downloaded successfully!`);
            } catch (error) {
                console.error('spotDL command execution failed:', error);
                Spicetify.showNotification(`Failed to download "${contentName}". Check console and local server logs.`);
            }
        } catch (error) {
            console.error('Error preparing download:', error);
            Spicetify.showNotification("Error preparing download. See console for details.");
        }
    }

    // --- Custom Button Injection ---

    /**
     * Injects a custom "Download with spotDL" button into the Spotify action bar.
     * This button will trigger the downloadSpotifyContent function.
     */
    function injectCustomButton() {
        const actionBar = document.querySelector('.main-actionBar-ActionBar');

        // Check if the action bar exists and our button isn't already injected
        if (actionBar && !document.getElementById('spotdl-download-button')) {
            // Create "Download with spotDL" button
            const downloadBtn = document.createElement('button');
            downloadBtn.id = 'spotdl-download-button';
            // Use Spotify's original button classes for consistent layout behavior
            downloadBtn.className = 'main-button-button main-actionButton-squareButton';
            
            // Apply specific styles to make it circular and icon-only
            downloadBtn.style.minWidth = '32px';
            downloadBtn.style.width = '32px';
            downloadBtn.style.height = '32px';
            downloadBtn.style.borderRadius = '50%';
            downloadBtn.style.backgroundColor = 'transparent';
            downloadBtn.style.color = 'var(--spice-text)';
            downloadBtn.style.display = 'flex';
            downloadBtn.style.justifyContent = 'center';
            downloadBtn.style.alignItems = 'center';
            downloadBtn.style.border = 'none';
            downloadBtn.style.cursor = 'pointer';

            // Set the SVG icon
            downloadBtn.innerHTML = `
                <svg role="img" height="20" width="20" aria-hidden="true" viewBox="0 0 24 24" data-encore-id="icon" class="Svg-sc-ytk21e-0 kAlJjW">
                    <path fill="currentColor" d="M12 2.75a9.25 9.25 0 1 0 0 18.5 9.25 9.25 0 0 0 0-18.5ZM1.25 12A10.75 10.75 0 1 1 12 22.75 10.75 10.75 0 0 1 1.25 12ZM12 7.75a.75.75 0 0 1 .75.75v3.69L14.78 10.53a.75.75 0 0 1 1.06 1.06l-3.25 3.25a.75.75 0 0 1-1.06 0l-3.25-3.25a.75.75 0 0 1 1.06-1.06l1.97 1.97V8.5a.75.75 0 0 1 .75-.75Z"></path>
                </svg>
            `;
            downloadBtn.onclick = downloadSpotifyContent; // Assign handler to the new button

            // Find an existing button to insert before (e.g., 'More options' or 'Like')
            const existingButton = actionBar.querySelector('.main-button-button[aria-label*="Like"], .main-button-button[aria-label*="More options"]');
            if (existingButton) {
                // Insert our button before an existing one for better placement
                actionBar.insertBefore(downloadBtn, existingButton);
            } else {
                // Fallback: just append to the end of the action bar
                actionBar.appendChild(downloadBtn);
            }
            console.log('SpotifyDownloader: Injected custom button');
        }
    }

    /**
     * Removes the custom button from the DOM.
     */
    function removeCustomButton() {
        const downloadBtn = document.getElementById('spotdl-download-button');
        if (downloadBtn) downloadBtn.remove();
    }

    /**
     * Waits for the Spotify action bar to appear in the DOM and then injects the custom button.
     */
    function waitForActionBarAndInjectButton() {
        const actionBar = document.querySelector('.main-actionBar-ActionBar');
        if (actionBar) {
            injectCustomButton();
        } else {
            // Keep trying until the action bar is found
            setTimeout(waitForActionBarAndInjectButton, 500);
        }
    }

    // --- Main Execution Flow ---

    // 1. Create the path prompt modal once
    createPathPromptModal();

    // 2. Use a MutationObserver to detect DOM changes and re-inject buttons when needed
    const observer = new MutationObserver(mutations => {
        const uri = Spicetify.Platform.History.location.pathname;
        if ((uri.includes('/playlist/') || uri.includes('/track/')) && !document.getElementById('spotdl-download-button')) {
            waitForActionBarAndInjectButton();
        }
    });

    observer.observe(document.body, {
        childList: true,
        subtree: true
    });

    // 3. Listen to Spicetify's history changes to handle navigation between pages
    Spicetify.Platform.History.listen(location => {
        if (location.pathname.includes('/playlist/') || location.pathname.includes('/track/')) {
            setTimeout(waitForActionBarAndInjectButton, 500);
        } else {
            removeCustomButton();
        }
    });

    // 4. Initial check: Inject button if already on a playlist or track page when the extension loads
    const initialUri = Spicetify.Platform.History.location.pathname;
    if (initialUri.includes('/playlist/') || initialUri.includes('/track/')) {
        waitForActionBarAndInjectButton();
    }

    console.log('SpotifyDownloader extension loaded with individual song download!');
})();
