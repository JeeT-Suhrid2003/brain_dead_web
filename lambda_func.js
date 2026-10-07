// Node.js 18+ (AWS SDK v3)
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, UpdateCommand } from "@aws-sdk/lib-dynamodb";

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);

export const handler = async (event) => {
  const command = new UpdateCommand({
    TableName: "SiteMetrics",
    Key: { MetricID: "click_count" },
    UpdateExpression: "ADD total_clicks :inc",
    ExpressionAttributeValues: { ":inc": 1 },
    ReturnValues: "UPDATED_NEW",
  });

  try {
    const response = await docClient.send(command);
    return {
      statusCode: 200,
      headers: {
        "Access-Control-Allow-Origin": "*", // Configure CORS properly
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ count: response.Attributes.total_clicks }),
    };
  } catch (error) {
    return { statusCode: 500, body: JSON.stringify({ error: error.message }) };
  }
};