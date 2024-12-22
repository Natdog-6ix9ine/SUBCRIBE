name: Weekly Run and Update Gist

on:
  schedule:
    - cron: '0 0 * * 0'
  workflow_dispatch:

jobs:
  run-script-and-update-gist:
    runs-on: ubuntu-latest

    env:
      SUBLINK: ${{ secrets.SUBLINK }}
      GIST_TOKEN: ${{ secrets.GIST_TOKEN }}
      GIST_ID: ${{ secrets.GIST_ID }}

    steps:
    - name: Checkout repository
      uses: actions/checkout@v3

    - name: Run the script
      run: |
        echo "Running run.sh script..."
        chmod +x run.sh
        ./run.sh

    - name: Check file exists
      run: |
        if [ ! -f config.yaml ]; then
          echo "Error: config.yaml not found!"
          exit 1
        fi
        echo "config.yaml exists."
        ls -l config.yaml

    - name: Upload to Gist
      run: |
        # 使用base64编码文件内容
        CONTENT=$(base64 -w 0 config.yaml)
        
        # 构建请求体
        echo '{
          "files": {
            "config.yaml": {
              "content": "'"$(base64 -d <<< "$CONTENT")"'"
            }
          }
        }' > payload.json

        # 发送请求并保存响应
        HTTP_RESPONSE=$(curl -s -w "%{http_code}" \
          -X PATCH \
          -H "Accept: application/vnd.github+json" \
          -H "Authorization: Bearer $GIST_TOKEN" \
          -H "X-GitHub-Api-Version: 2022-11-28" \
          https://api.github.com/gists/$GIST_ID \
          -d @payload.json)
        
        # 提取状态码
        HTTP_STATUS=${HTTP_RESPONSE: -3}
        BODY=${HTTP_RESPONSE:0:${#HTTP_RESPONSE}-3}
        
        # 检查响应状态
        if [ $HTTP_STATUS -eq 200 ]; then
          echo "Successfully updated gist"
          echo "Response: $BODY"
        else
          echo "Failed to update gist"
          echo "Status code: $HTTP_STATUS"
          echo "Response body: $BODY"
          exit 1
        fi

    - name: Cleanup
      if: always()
      run: rm -f payload.json

    - name: Success message
      run: echo "Workflow completed successfully!"