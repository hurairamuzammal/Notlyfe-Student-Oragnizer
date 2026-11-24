import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const HTML = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Reset Password - Notlyfe</title>
  <script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>
  <style>
    * {
      box-sizing: border-box;
      margin: 0;
      padding: 0;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    }
    body {
      background: #0f172a;
      color: #f8fafc;
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 20px;
    }
    .card {
      background: #1e293b;
      border: 1px solid #334155;
      border-radius: 20px;
      padding: 36px 30px;
      width: 100%;
      max-width: 420px;
      box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.5);
    }
    .header {
      text-align: center;
      margin-bottom: 26px;
    }
    .logo {
      font-size: 38px;
      font-weight: 800;
      color: #38bdf8;
      letter-spacing: -0.5px;
      margin-bottom: 6px;
    }
    .subtitle {
      color: #94a3b8;
      font-size: 14px;
    }
    .form-group {
      margin-bottom: 20px;
    }
    label {
      display: block;
      font-size: 13px;
      font-weight: 600;
      color: #cbd5e1;
      margin-bottom: 8px;
    }
    input[type="password"] {
      width: 100%;
      padding: 13px 15px;
      border-radius: 10px;
      border: 1px solid #475569;
      background: #0f172a;
      color: #f8fafc;
      font-size: 15px;
      outline: none;
      transition: border-color 0.2s, box-shadow 0.2s;
    }
    input[type="password"]:focus {
      border-color: #38bdf8;
      box-shadow: 0 0 0 3px rgba(56, 189, 248, 0.15);
    }
    .btn {
      width: 100%;
      padding: 14px;
      background: #0284c7;
      color: white;
      border: none;
      border-radius: 10px;
      font-size: 15px;
      font-weight: 600;
      cursor: pointer;
      margin-top: 8px;
      transition: background 0.2s, transform 0.1s;
    }
    .btn:hover {
      background: #0369a1;
    }
    .btn:active {
      transform: scale(0.99);
    }
    .btn:disabled {
      background: #475569;
      cursor: not-allowed;
      transform: none;
    }
    .alert {
      padding: 14px;
      border-radius: 10px;
      font-size: 14px;
      margin-bottom: 20px;
      display: none;
      line-height: 1.5;
    }
    .alert-error {
      background: rgba(239, 68, 68, 0.15);
      border: 1px solid #ef4444;
      color: #fca5a5;
    }
    .alert-success {
      background: rgba(34, 197, 94, 0.15);
      border: 1px solid #22c55e;
      color: #86efac;
    }
    .alert-info {
      background: rgba(56, 189, 248, 0.15);
      border: 1px solid #38bdf8;
      color: #7dd3fc;
      display: block;
    }
    .open-app-btn {
      display: inline-block;
      margin-top: 16px;
      padding: 12px 20px;
      background: #10b981;
      color: white;
      border-radius: 8px;
      text-decoration: none;
      font-weight: 600;
      font-size: 14px;
    }
  </style>
</head>
<body>
  <div class="card">
    <div class="header">
      <div class="logo">Notlyfe</div>
      <p class="subtitle">Set a new password for your account</p>
    </div>

    <div id="alert-box" class="alert"></div>

    <form id="reset-form">
      <div class="form-group">
        <label for="new-password">New Password</label>
        <input type="password" id="new-password" placeholder="At least 6 characters" required minlength="6" autocomplete="new-password">
      </div>
      <div class="form-group">
        <label for="confirm-password">Confirm Password</label>
        <input type="password" id="confirm-password" placeholder="Re-enter new password" required minlength="6" autocomplete="new-password">
      </div>
      <button type="submit" id="submit-btn" class="btn">Update Password</button>
    </form>
  </div>

  <script>
    const SUPABASE_URL = "https://ldnlbuextqhnslzephpu.supabase.co";
    const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxkbmxidWV4dHFobnNsemVwaHB1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE5NTM4NzEsImV4cCI6MjEwNzUyOTg3MX0.6ET6oBSNWGqKc5rIFGkTOzv1vpGV2d_EP6d-hD2mSGk";

    const supabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

    const alertBox = document.getElementById("alert-box");
    const form = document.getElementById("reset-form");
    const submitBtn = document.getElementById("submit-btn");

    function showAlert(msg, type, allowOpenAppLink = false) {
      alertBox.textContent = "";
      alertBox.className = "alert " + (type === "error" ? "alert-error" : type === "success" ? "alert-success" : "alert-info");

      if (allowOpenAppLink) {
        const strong = document.createElement("strong");
        strong.textContent = "Password updated successfully!";
        const desc = document.createElement("div");
        desc.style.marginTop = "6px";
        desc.textContent = "You can now open Notlyfe and sign in with your new password.";
        const link = document.createElement("a");
        link.href = "notlyfe://";
        link.className = "open-app-btn";
        link.textContent = "Open Notlyfe App";
        alertBox.append(strong, desc, link);
      } else {
        alertBox.textContent = String(msg ?? "");
      }
      alertBox.style.display = "block";
    }

    // Check if recovery session exists or code needs exchanging
    async function initSession() {
      // 1. Check for PKCE 'code' query param
      const urlParams = new URLSearchParams(window.location.search);
      const code = urlParams.get("code");
      if (code) {
        try {
          const { error } = await supabase.auth.exchangeCodeForSession(code);
          if (error) {
            showAlert("Failed to verify recovery link: " + error.message, "error");
            return;
          }
        } catch (e) {
          showAlert("Error verifying code: " + e.message, "error");
          return;
        }
      }

      // 2. Check for token_hash and type=recovery
      const tokenHash = urlParams.get("token_hash");
      const type = urlParams.get("type");
      if (tokenHash && type === "recovery") {
        try {
          const { error } = await supabase.auth.verifyOtp({ token_hash: tokenHash, type: "recovery" });
          if (error) {
            showAlert("Failed to verify recovery token: " + error.message, "error");
            return;
          }
        } catch (e) {
          showAlert("Error verifying token: " + e.message, "error");
          return;
        }
      }

      // 3. Check for hash parameters (#access_token=...&refresh_token=...)
      if (window.location.hash) {
        const hash = window.location.hash.substring(1);
        const hashParams = new URLSearchParams(hash);
        const errorDesc = hashParams.get("error_description");
        const accessToken = hashParams.get("access_token");
        const refreshToken = hashParams.get("refresh_token");

        if (errorDesc) {
          showAlert("Link error: " + decodeURIComponent(errorDesc.replace(/\+/g, " ")), "error");
          return;
        }

        if (accessToken && refreshToken) {
          try {
            await supabase.auth.setSession({ access_token: accessToken, refresh_token: refreshToken });
          } catch (e) {
            console.error("setSession error", e);
          }
        }
      }
    }

    initSession();

    form.addEventListener("submit", async (e) => {
      e.preventDefault();
      const pwd = document.getElementById("new-password").value.trim();
      const confirmPwd = document.getElementById("confirm-password").value.trim();

      if (pwd.length < 6) {
        showAlert("Password must be at least 6 characters.", "error");
        return;
      }

      if (pwd !== confirmPwd) {
        showAlert("Passwords do not match.", "error");
        return;
      }

      submitBtn.disabled = true;
      submitBtn.textContent = "Updating...";

      try {
        const { data: sessionData } = await supabase.auth.getSession();
        if (!sessionData || !sessionData.session) {
          showAlert("No active recovery session found. Please click the link in your email again or request a new password reset.", "error");
          submitBtn.disabled = false;
          submitBtn.textContent = "Update Password";
          return;
        }

        const { data, error } = await supabase.auth.updateUser({ password: pwd });
        if (error) {
          showAlert(error.message, "error");
          submitBtn.disabled = false;
          submitBtn.textContent = "Update Password";
        } else {
          showAlert("", "success", true);
          form.style.display = "none";
        }
      } catch (err) {
        showAlert("An unexpected error occurred: " + err.message, "error");
        submitBtn.disabled = false;
        submitBtn.textContent = "Update Password";
      }
    });
  </script>
</body>
</html>`;

serve((req) => {
  return new Response(HTML, {
    status: 200,
    headers: {
      "Content-Type": "text/html; charset=utf-8",
      "Cache-Control": "no-store",
      "X-Content-Type-Options": "nosniff",
      "X-Frame-Options": "DENY",
      "Referrer-Policy": "no-referrer",
    },
  });
});
