import {
  DynamoDBClient,
  UpdateItemCommand,
} from "@aws-sdk/client-dynamodb";

const ddb = new DynamoDBClient({});

const {
  MAIN_TABLE_NAME = "",
  TABLE_PARTITION_KEY = "pk",
  TABLE_SORT_KEY = "sk",
  WORKER_RESULT_TTL_DAYS = "14",
} = process.env;

function toStringAttr(value) {
  return { S: String(value) };
}

function toNumberAttr(value) {
  return { N: String(value) };
}

async function markFailed(taskId, now, reason) {
  if (!MAIN_TABLE_NAME || !taskId) {
    return;
  }
  await ddb.send(
    new UpdateItemCommand({
      TableName: MAIN_TABLE_NAME,
      Key: {
        [TABLE_PARTITION_KEY]: toStringAttr(`TASK#${taskId}`),
        [TABLE_SORT_KEY]: toStringAttr(`TASK#${taskId}`),
      },
      UpdateExpression:
        "SET #status = :status, #updatedAt = :updatedAt, #result = :result",
      ExpressionAttributeNames: {
        "#status": "status",
        "#updatedAt": "updatedAt",
        "#result": "result",
      },
      ExpressionAttributeValues: {
        ":status": toStringAttr("FAILED"),
        ":updatedAt": toStringAttr(now),
        ":result": toStringAttr(JSON.stringify({ error: reason })),
      },
    })
  );
}

export const handler = async (event) => {
  const records = event.Records || [];
  const ttlDays = Number.parseInt(WORKER_RESULT_TTL_DAYS, 10);

  for (const record of records) {
    let payload = {};
    try {
      payload = JSON.parse(record.body || "{}");
    } catch {
      payload = {};
    }

    const {
      taskId,
      requestedBy = "system",
      input = {},
      metadata = {},
    } = payload;

    if (!taskId || !MAIN_TABLE_NAME) {
      continue;
    }

    const now = new Date().toISOString();
    const summary = {
      message: "Base worker processed queued task.",
      taskId,
      processedAt: now,
      requestedBy,
      input,
      metadata,
      queueMessageId: record.messageId || null,
    };

    try {
      await ddb.send(
        new UpdateItemCommand({
          TableName: MAIN_TABLE_NAME,
          Key: {
            [TABLE_PARTITION_KEY]: toStringAttr(`TASK#${taskId}`),
            [TABLE_SORT_KEY]: toStringAttr(`TASK#${taskId}`),
          },
          UpdateExpression:
            "SET #status = :status, #updatedAt = :updatedAt, #result = :result, #completedAt = :completedAt, #ttl = :ttl",
          ExpressionAttributeNames: {
            "#status": "status",
            "#updatedAt": "updatedAt",
            "#result": "result",
            "#completedAt": "completedAt",
            "#ttl": "expiresAt",
          },
          ExpressionAttributeValues: {
            ":status": toStringAttr("SUCCEEDED"),
            ":updatedAt": toStringAttr(now),
            ":result": toStringAttr(JSON.stringify(summary)),
            ":completedAt": toStringAttr(now),
            ":ttl": toNumberAttr(Math.floor(Date.now() / 1000) + ttlDays * 24 * 60 * 60),
          },
        })
      );
    } catch (error) {
      await markFailed(taskId, now, error?.message || "Worker update failed");
      throw error;
    }
  }
};
