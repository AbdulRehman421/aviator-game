# Deploy to Glitch.com (Instant & Free)

## Steps:

1. Go to: https://glitch.com
2. Click "New Project" → "glitch-hello-node"
3. Delete all files
4. Upload your `server/index.js`
5. Create `package.json`:

```json
{
  "name": "aviator-game",
  "version": "1.0.0",
  "main": "index.js",
  "scripts": {
    "start": "node index.js"
  },
  "dependencies": {
    "firebase-admin": "^12.0.0"
  }
}
```

6. Click "Tools" → "Terminal"
7. Run: `npm install`
8. Your server is live!

## Your URLs:
- Server: `https://your-project-name.glitch.me`
- Editor: `https://glitch.com/edit/#!/your-project-name`

## Keep it alive:
Glitch sleeps after 5 min inactivity. Use a keep-alive service:
- https://uptimerobot.com (FREE)
- Pings your server every 5 minutes
