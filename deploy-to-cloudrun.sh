#!/bin/bash

# ========================================
# Cloud Run 部署腳本（適用於 Cloud Shell）
# ========================================

set -e  # 遇到錯誤立即停止

echo "🚀 開始部署 Vue 3 通訊錄到 Cloud Run"
echo ""

# ========================================
# 1. 設定變數（請修改這些值）
# ========================================

# 替換為您的 GCP 專案 ID
PROJECT_ID="rain-station-app"

# 替換為您的後端 URL（先部署後端後取得）

# 其他設定
REGION="asia-east1"
ARTIFACT_REPO="rain-app-repo"
SERVICE_NAME="rain-app-frontend"

echo "📋 部署設定："
echo "  專案 ID: $PROJECT_ID"
echo "  區域: $REGION"
echo "  服務名稱: $SERVICE_NAME"
echo ""

# ========================================
# 2. 確認設定
# ========================================

if [ "$PROJECT_ID" = "your-project-id" ]; then
    echo "❌ 錯誤：請先設定 PROJECT_ID"
    echo ""
    echo "使用方式："
    echo "  export PROJECT_ID=\"your-actual-project-id\""
    echo "  ./deploy-to-cloudrun.sh"
    exit 1
fi

read -p "確認以上設定正確？(y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ 已取消部署"
    exit 1
fi

# ========================================
# 3. 設定 GCP 專案
# ========================================

echo "🔧 設定 GCP 專案..."
gcloud config set project $PROJECT_ID

# ========================================
# 4. 啟用必要的 API
# ========================================

echo "🔌 啟用必要的 API..."
gcloud services enable \
    cloudbuild.googleapis.com \
    run.googleapis.com \
    artifactregistry.googleapis.com

# ========================================
# 5. 建立 Artifact Registry（如果不存在）
# ========================================

echo "📦 檢查 Artifact Registry..."
if gcloud artifacts repositories describe $ARTIFACT_REPO --location=$REGION >/dev/null 2>&1; then
    echo "  ✓ Repository 已存在"
else
    echo "  建立 Repository..."
    gcloud artifacts repositories create $ARTIFACT_REPO \
        --repository-format=docker \
        --location=$REGION \
        --description="Docker repository for Vue3 application"
fi

# ========================================
# 6. 設定 Docker 認證
# ========================================

echo "🔐 設定 Docker 認證..."
gcloud auth configure-docker ${REGION}-docker.pkg.dev --quiet

# ========================================
# 7. 授予 Cloud Build 權限（如果需要）
# ========================================

echo "🔑 檢查 Cloud Build 權限..."
PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')

# 檢查是否已有權限
if gcloud projects get-iam-policy $PROJECT_ID --flatten="bindings[].members" \
    --filter="bindings.members:serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com AND bindings.role:roles/run.admin" \
    --format="value(bindings.role)" | grep -q "roles/run.admin"; then
    echo "  ✓ Cloud Build 已有部署權限"
else
    echo "  授予 Cloud Build 部署權限..."
    gcloud projects add-iam-policy-binding $PROJECT_ID \
        --member=serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com \
        --role=roles/run.admin \
        --condition=None \
        --quiet

    gcloud iam service-accounts add-iam-policy-binding \
        ${PROJECT_NUMBER}-compute@developer.gserviceaccount.com \
        --member=serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com \
        --role=roles/iam.serviceAccountUser \
        --condition=None \
        --quiet
fi

# ========================================
# 8. 建構 Docker Image
# ========================================

echo "🏗️  建構 Docker Image..."
IMAGE_TAG="${REGION}-docker.pkg.dev/${PROJECT_ID}/${ARTIFACT_REPO}/${SERVICE_NAME}:latest"

docker build \
    -t $IMAGE_TAG \
    .

# ========================================
# 9. 推送到 Artifact Registry
# ========================================

echo "📤 推送 Image 到 Artifact Registry..."
docker push $IMAGE_TAG

# ========================================
# 10. 部署到 Cloud Run
# ========================================

echo "🚢 部署到 Cloud Run..."
gcloud run deploy $SERVICE_NAME \
    --image=$IMAGE_TAG \
    --region=$REGION \
    --platform=managed \
    --allow-unauthenticated \
    --port=8080 \
    --memory=256Mi \
    --cpu=1 \
    --min-instances=0 \
    --max-instances=10 \
    --timeout=300 \
    --concurrency=80 \
    --quiet

# ========================================
# 11. 取得服務 URL
# ========================================

echo ""
echo "✅ 部署完成！"
echo ""

SERVICE_URL=$(gcloud run services describe $SERVICE_NAME \
    --region=$REGION \
    --format='value(status.url)')

echo "🌐 前端 URL: $SERVICE_URL"
echo ""
echo "📋 下一步："
echo "  1. 訪問前端 URL 測試應用程式"
echo "  2. 檢查 API 請求是否正常"
echo "  3. 更新後端 CORS 設定，加入前端 URL：$SERVICE_URL"
echo ""
echo "📊 查看日誌："
echo "  gcloud run services logs read $SERVICE_NAME --region=$REGION --limit=50"
echo ""
