import Foundation

/// Provides the embedded HTML/CSS/JavaScript web client served to the viewing device.
enum WebClientContent {
    
    static let html: String = """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover">
      <title>DuoMirror &bull; Live View</title>
      <style>
        :root {
          --bg-color: #0b0f19;
          --panel-bg: rgba(18, 24, 38, 0.85);
          --accent-color: #3b82f6;
          --accent-hover: #2563eb;
          --danger-color: #ef4444;
          --success-color: #10b981;
          --text-main: #f3f4f6;
          --text-muted: #9ca3af;
        }

        * {
          box-sizing: border-box;
          margin: 0;
          padding: 0;
          -webkit-user-select: none;
          user-select: none;
          -webkit-tap-highlight-color: transparent;
        }

        body, html {
          width: 100%;
          height: 100%;
          height: 100dvh;
          overflow: hidden;
          background-color: var(--bg-color);
          font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
          color: var(--text-main);
        }

        #app-container {
          position: relative;
          width: 100%;
          height: 100%;
          height: 100dvh;
          display: flex;
          flex-direction: column;
          align-items: center;
          justify-content: center;
        }

        /* Video Canvas */
        #viewport {
          position: absolute;
          top: 0;
          left: 0;
          width: 100%;
          height: 100%;
          display: flex;
          align-items: center;
          justify-content: center;
          background: #000;
        }

        canvas {
          max-width: 100%;
          max-height: 100%;
          width: 100%;
          height: 100%;
          object-fit: contain;
          transition: transform 0.15s ease-out;
        }

        /* Mirrored View (Default) */
        .mirrored {
          transform: scaleX(-1);
        }

        .unmirrored {
          transform: scaleX(1);
        }

        /* Top Status Bar */
        #top-bar {
          position: absolute;
          top: env(safe-area-inset-top, 16px);
          left: 14px;
          right: 14px;
          display: flex;
          justify-content: space-between;
          align-items: center;
          z-index: 20;
          pointer-events: none;
        }

        .status-badge {
          pointer-events: auto;
          background: var(--panel-bg);
          backdrop-filter: blur(12px);
          -webkit-backdrop-filter: blur(12px);
          border: 1px solid rgba(255, 255, 255, 0.12);
          padding: 6px 12px;
          border-radius: 9999px;
          font-size: 12px;
          font-weight: 600;
          display: flex;
          align-items: center;
          gap: 6px;
          box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
        }

        .status-dot {
          width: 8px;
          height: 8px;
          border-radius: 50%;
          background-color: var(--success-color);
          box-shadow: 0 0 8px var(--success-color);
        }

        .status-dot.disconnected {
          background-color: var(--danger-color);
          box-shadow: 0 0 8px var(--danger-color);
        }

        /* Top Right Action & Frozen Badge */
        .top-right {
          display: flex;
          align-items: center;
          gap: 8px;
          pointer-events: auto;
        }

        #frozen-badge {
          display: none;
          background: rgba(239, 68, 68, 0.9);
          color: white;
          padding: 4px 10px;
          border-radius: 6px;
          font-size: 11px;
          font-weight: 700;
          letter-spacing: 0.05em;
          text-transform: uppercase;
        }

        .top-btn {
          border: 1px solid rgba(255, 255, 255, 0.14);
          background: var(--panel-bg);
          backdrop-filter: blur(12px);
          -webkit-backdrop-filter: blur(12px);
          color: var(--text-main);
          font-size: 12px;
          font-weight: 600;
          padding: 6px 12px;
          border-radius: 9999px;
          cursor: pointer;
          display: flex;
          align-items: center;
          gap: 5px;
          box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
          transition: all 0.15s ease-in-out;
        }

        .top-btn:active {
          transform: scale(0.94);
        }

        .top-btn.active {
          background: rgba(255, 255, 255, 0.22);
          border-color: rgba(255, 255, 255, 0.35);
        }

        /* Floating Controls Container */
        #controls-container {
          position: absolute;
          bottom: calc(env(safe-area-inset-bottom, 16px) + 12px);
          left: 0;
          right: 0;
          display: flex;
          justify-content: center;
          padding: 0 10px;
          z-index: 30;
          pointer-events: none;
        }

        #controls-bar {
          pointer-events: auto;
          display: flex;
          align-items: center;
          gap: 6px;
          background: var(--panel-bg);
          backdrop-filter: blur(16px);
          -webkit-backdrop-filter: blur(16px);
          border: 1px solid rgba(255, 255, 255, 0.14);
          border-radius: 30px;
          padding: 5px 8px;
          box-shadow: 0 8px 24px rgba(0, 0, 0, 0.5);
          max-width: 100%;
          overflow-x: auto;
          overflow-y: hidden;
          -webkit-overflow-scrolling: touch;
          scrollbar-width: none;
          overscroll-behavior-x: contain;
        }

        #controls-bar::-webkit-scrollbar {
          display: none;
          width: 0;
          height: 0;
        }

        button.btn {
          flex-shrink: 0;
          white-space: nowrap;
          border: none;
          background: rgba(255, 255, 255, 0.08);
          color: var(--text-main);
          font-size: 12px;
          font-weight: 600;
          padding: 7px 11px;
          border-radius: 18px;
          cursor: pointer;
          display: flex;
          align-items: center;
          justify-content: center;
          gap: 5px;
          transition: all 0.15s ease-in-out;
        }

        button.btn:active {
          transform: scale(0.94);
        }

        button.btn:disabled {
          opacity: 0.32;
          cursor: not-allowed;
          pointer-events: none;
        }

        button.btn.active {
          background: var(--accent-color);
          color: #fff;
          box-shadow: 0 0 12px rgba(59, 130, 246, 0.5);
        }

        button.btn.frozen-active {
          background: var(--danger-color);
          color: white;
          box-shadow: 0 0 12px rgba(239, 68, 68, 0.5);
        }

        .zoom-group {
          flex-shrink: 0;
          display: flex;
          background: rgba(0, 0, 0, 0.35);
          border-radius: 18px;
          padding: 2px 3px;
          gap: 2px;
          align-items: center;
        }

        .zoom-tag {
          font-size: 9px;
          font-weight: 800;
          color: var(--text-muted);
          padding: 0 3px 0 6px;
          letter-spacing: 0.05em;
        }

        .zoom-btn {
          border: none;
          background: transparent;
          color: var(--text-muted);
          font-size: 11px;
          font-weight: 700;
          padding: 5px 8px;
          border-radius: 14px;
          cursor: pointer;
          transition: all 0.12s ease;
        }

        .zoom-btn.selected {
          background: var(--accent-color);
          color: white;
        }

        /* Reconnecting Overlay */
        #overlay-msg {
          position: absolute;
          inset: 0;
          background: rgba(11, 15, 25, 0.85);
          display: flex;
          flex-direction: column;
          align-items: center;
          justify-content: center;
          gap: 16px;
          z-index: 10;
        }

        .spinner {
          width: 42px;
          height: 42px;
          border: 4px solid rgba(255, 255, 255, 0.1);
          border-top-color: var(--accent-color);
          border-radius: 50%;
          animation: spin 0.8s linear infinite;
        }

        @keyframes spin {
          to { transform: rotate(360deg); }
        }
      </style>
    </head>
    <body>
      <div id="app-container">
        <!-- Top Status Bar -->
        <div id="top-bar">
          <div class="status-badge">
            <span class="status-dot" id="dot"></span>
            <span id="status-text">Connecting...</span>
            <span style="color: var(--text-muted);">&bull;</span>
            <span id="fps-counter">-- fps</span>
          </div>

          <div class="top-right">
            <div id="frozen-badge">FROZEN</div>
            <button class="top-btn" id="btn-flip" title="Toggle horizontal mirror reflection">
              <span>🪞</span> Mirror
            </button>
          </div>
        </div>

        <!-- Video Viewport -->
        <div id="viewport">
          <canvas id="mirror" class="mirrored"></canvas>
        </div>

        <!-- Connecting / Error Overlay -->
        <div id="overlay-msg">
          <div class="spinner"></div>
          <p style="font-weight: 600; font-size: 16px;">Connecting to DuoMirror Camera...</p>
          <p style="font-size: 13px; color: var(--text-muted);">Ensure both phones are on the same Wi-Fi or Hotspot</p>
        </div>

        <!-- Bottom Controls Bar -->
        <div id="controls-container">
          <div id="controls-bar">
            <!-- Torch Toggle -->
            <button class="btn" id="btn-torch" title="Toggle Flashlight">
              <span id="torch-icon">💡</span> Torch
            </button>

            <!-- Switch Front/Back Camera -->
            <button class="btn" id="btn-camera" title="Switch between Front and Back Camera">
              <span id="cam-icon" style="display:inline-block; transition: transform 0.3s ease;">🔄</span> Camera
            </button>

            <!-- Zoom Selector -->
            <div class="zoom-group">
              <span class="zoom-tag">ZOOM</span>
              <button class="zoom-btn selected" data-zoom="1.0">1x</button>
              <button class="zoom-btn" data-zoom="2.0">2x</button>
              <button class="zoom-btn" data-zoom="3.0">3x</button>
            </div>

            <!-- Freeze Frame -->
            <button class="btn" id="btn-freeze" title="Freeze frame to inspect">
              <span>❄️</span> Freeze
            </button>
          </div>
        </div>
      </div>

      <script>
        const canvas = document.getElementById('mirror');
        const ctx = canvas.getContext('2d');
        const dot = document.getElementById('dot');
        const statusText = document.getElementById('status-text');
        const fpsCounter = document.getElementById('fps-counter');
        const overlay = document.getElementById('overlay-msg');
        const frozenBadge = document.getElementById('frozen-badge');
        const btnTorch = document.getElementById('btn-torch');
        const btnCamera = document.getElementById('btn-camera');
        const btnFreeze = document.getElementById('btn-freeze');
        const btnFlip = document.getElementById('btn-flip');
        const zoomBtns = document.querySelectorAll('.zoom-btn');

        let ws = null;
        let isFrozen = false;
        let isTorchOn = false;
        let isMirrored = true;
        let currentZoom = 1.0;
        let frameCount = 0;
        let lastFpsTime = performance.now();

        // FPS calculation
        function trackFrame() {
          frameCount++;
          const now = performance.now();
          if (now - lastFpsTime >= 1000) {
            const fps = Math.round((frameCount * 1000) / (now - lastFpsTime));
            fpsCounter.textContent = `${fps} fps`;
            frameCount = 0;
            lastFpsTime = now;
          }
        }

        // Screen Wake Lock (keep screen awake while inspecting)
        async function requestWakeLock() {
          if ('wakeLock' in navigator) {
            try {
              await navigator.wakeLock.request('screen');
            } catch (err) {
              console.log('Wake Lock error:', err);
            }
          }
        }
        document.addEventListener('visibilitychange', () => {
          if (document.visibilityState === 'visible') requestWakeLock();
        });
        requestWakeLock();

        // Connect WebSocket
        function connect() {
          const wsProtocol = location.protocol === 'https:' ? 'wss:' : 'ws:';
          const wsUrl = `${wsProtocol}//${location.host}/ws`;

          ws = new WebSocket(wsUrl);
          ws.binaryType = 'blob';

          ws.onopen = () => {
            overlay.style.display = 'none';
            dot.className = 'status-dot';
            statusText.textContent = 'Live Mirror';
            // Sync initial state
            send({ type: 'sync_request' });
          };

          ws.onmessage = async (event) => {
            if (event.data instanceof Blob) {
              if (isFrozen) return; // Ignore new frames when frozen

              trackFrame();

              // Use fast GPU createImageBitmap
              try {
                const bitmap = await createImageBitmap(event.data);
                if (canvas.width !== bitmap.width || canvas.height !== bitmap.height) {
                  canvas.width = bitmap.width;
                  canvas.height = bitmap.height;
                }
                ctx.drawImage(bitmap, 0, 0);
                bitmap.close();
              } catch (e) {
                // Fallback to Image
                const img = new Image();
                img.onload = () => {
                  canvas.width = img.width;
                  canvas.height = img.height;
                  ctx.drawImage(img, 0, 0);
                  URL.revokeObjectURL(img.src);
                };
                img.src = URL.createObjectURL(event.data);
              }
            } else {
              // JSON control message from iPhone
              try {
                const msg = JSON.parse(event.data);
                if (msg.type === 'state_update') {
                  if (msg.hasTorch !== undefined) {
                    btnTorch.disabled = !msg.hasTorch;
                    btnTorch.title = msg.hasTorch ? 'Toggle Flashlight' : 'Torch unavailable on front camera';
                    if (!msg.hasTorch) {
                      isTorchOn = false;
                      btnTorch.classList.remove('active');
                    }
                  }
                  if (msg.torch !== undefined) {
                    isTorchOn = !!msg.torch;
                    btnTorch.classList.toggle('active', isTorchOn);
                  }
                  if (msg.allowCameraSwitch !== undefined) {
                    btnCamera.style.display = msg.allowCameraSwitch ? 'flex' : 'none';
                  }
                  if (msg.zoom !== undefined) {
                    zoomBtns.forEach(b => {
                      b.classList.toggle('selected', Math.abs(parseFloat(b.dataset.zoom) - msg.zoom) < 0.1);
                    });
                  }
                }
              } catch (e) {}
            }
          };

          ws.onclose = () => {
            dot.className = 'status-dot disconnected';
            statusText.textContent = 'Disconnected';
            fpsCounter.textContent = '-- fps';
            overlay.style.display = 'flex';
            setTimeout(connect, 1500); // Auto reconnect
          };

          ws.onerror = () => {
            ws.close();
          };
        }

        function send(payload) {
          if (ws && ws.readyState === WebSocket.OPEN) {
            ws.send(JSON.stringify(payload));
          }
        }

        // Torch toggle
        btnTorch.addEventListener('click', () => {
          if (btnTorch.disabled) return;
          isTorchOn = !isTorchOn;
          btnTorch.classList.toggle('active', isTorchOn);
          send({ type: 'set_torch', value: isTorchOn });
        });

        // Switch camera with tactile icon flip & debounce
        let isSwitchingCamera = false;
        let camFlipped = false;
        btnCamera.addEventListener('click', () => {
          if (isSwitchingCamera) return;
          isSwitchingCamera = true;
          camFlipped = !camFlipped;
          const camIcon = document.getElementById('cam-icon');
          if (camIcon) {
            camIcon.style.transform = camFlipped ? 'rotate(180deg)' : 'rotate(0deg)';
          }
          send({ type: 'switch_camera' });
          setTimeout(() => { isSwitchingCamera = false; }, 400);
        });

        // Zoom selector
        zoomBtns.forEach(btn => {
          btn.addEventListener('click', () => {
            zoomBtns.forEach(b => b.classList.remove('selected'));
            btn.classList.add('selected');
            currentZoom = parseFloat(btn.dataset.zoom);
            send({ type: 'set_zoom', value: currentZoom });
          });
        });

        // Freeze frame
        btnFreeze.addEventListener('click', () => {
          isFrozen = !isFrozen;
          btnFreeze.classList.toggle('frozen-active', isFrozen);
          frozenBadge.style.display = isFrozen ? 'block' : 'none';
          btnFreeze.innerHTML = isFrozen ? '<span>▶️</span> Resume' : '<span>❄️</span> Freeze';
        });

        // Flip mirror horizontally
        btnFlip.addEventListener('click', () => {
          isMirrored = !isMirrored;
          canvas.className = isMirrored ? 'mirrored' : 'unmirrored';
          btnFlip.classList.toggle('active', !isMirrored);
          btnFlip.innerHTML = isMirrored ? '<span>🪞</span> Mirror' : '<span>↔️</span> Normal';
        });

        connect();
      </script>
    </body>
    </html>
    """
}
