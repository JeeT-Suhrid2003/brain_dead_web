# Tej Group

A single-file screensaver page with a shared click counter.

## Service flow

```text
Browser
  ├─ GET page → CloudFront → private S3 bucket (index.html)
  └─ POST /click → API Gateway → Lambda → DynamoDB (SiteMetrics)
```

CloudFront serves the static page over HTTPS. API Gateway sends counter clicks
to Lambda, which atomically increments `total_clicks` in DynamoDB. The browser
uses no AWS credentials.

## Configure

- DynamoDB table: `SiteMetrics`, partition key `MetricID` (String), on-demand
  capacity. Lambda creates the `click_count` item on its first update.
- Lambda: Node.js function using `lambda_func.js`; its execution role needs
  `dynamodb:UpdateItem` on the table.
- API Gateway: `POST /click` integrated with Lambda. Configure CORS to allow
  your exact CloudFront origin and the `POST` method.
- Frontend: Set `API_ENDPOINT` in `index.html` to the full deployed route URL,
  including `/click`, then upload `index.html` to S3 and invalidate the
  CloudFront cache.

The API response is JSON, for example `{"count":2}`. Keep the S3 bucket private
and do not put AWS credentials in the page.
