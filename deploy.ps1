#!/usr/bin/env pwsh
# UVExpress Admin Web - Quick Deploy Script

Write-Host "🚀 UVExpress Admin Web - Deployment Script" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Check if Firebase CLI is installed
Write-Host "📦 Checking Firebase CLI..." -ForegroundColor Yellow
$firebaseInstalled = Get-Command firebase -ErrorAction SilentlyContinue

if (-not $firebaseInstalled) {
    Write-Host "❌ Firebase CLI is not installed!" -ForegroundColor Red
    Write-Host ""
    Write-Host "To install Firebase CLI, run:" -ForegroundColor Yellow
    Write-Host "  npm install -g firebase-tools" -ForegroundColor White
    Write-Host ""
    exit 1
}

Write-Host "✅ Firebase CLI found" -ForegroundColor Green
Write-Host ""

# Ask user to confirm
Write-Host "🔍 Checking build folder..." -ForegroundColor Yellow
if (-not (Test-Path "build/web/index.html")) {
    Write-Host "❌ Build folder not found or incomplete!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Run the following command first:" -ForegroundColor Yellow
    Write-Host "  flutter build web --release" -ForegroundColor White
    Write-Host ""
    exit 1
}

Write-Host "✅ Build folder exists" -ForegroundColor Green
Write-Host ""

# Confirm deployment
$confirmation = Read-Host "Ready to deploy to Firebase Hosting? (y/N)"
if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
    Write-Host "❌ Deployment cancelled" -ForegroundColor Red
    exit 0
}

Write-Host ""
Write-Host "🚀 Deploying to Firebase Hosting..." -ForegroundColor Cyan
Write-Host ""

# Deploy
firebase deploy --only hosting

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✅ Deployment successful!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Your app is now live! 🎉" -ForegroundColor Cyan
} else {
    Write-Host ""
    Write-Host "❌ Deployment failed!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "  1. Make sure you're logged in: firebase login" -ForegroundColor White
    Write-Host "  2. Check your Firebase project ID in .firebaserc" -ForegroundColor White
    Write-Host "  3. Verify you have hosting permissions" -ForegroundColor White
}

Write-Host ""
