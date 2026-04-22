import crypto from "node:crypto";
import {
  DynamoDBClient,
  GetItemCommand,
  PutItemCommand,
} from "@aws-sdk/client-dynamodb";
import { SQSClient, SendMessageCommand } from "@aws-sdk/client-sqs";

const dynamodb = new DynamoDBClient({});
const sqs = new SQSClient({});

const tableName = process.env.MAIN_TABLE_NAME;
const queueUrl = process.env.TASK_QUEUE_URL;

function toStringAttr(value) {
  return { S: String(value) };
}

function toNumberAttr(value) {
  return { N: String(value) };
}

function toJsonStringAttr(value) {
  return toStringAttr(JSON.stringify(value));
}

function fromDynamoItem(item) {
  if (!item) {
    return null;
  }

  let parsedPayload = null;
  let parsedResult = null;

  if (item.payload?.S) {
    try {
      parsedPayload = JSON.parse(item.payload.S);
    } catch {
      parsedPayload = { raw: item.payload.S };
    }
  }

  if (item.result?.S) {
    try {
      parsedResult = JSON.parse(item.result.S);
    } catch {
      parsedResult = { raw: item.result.S };
    }
  }

  return {
    taskId: item.taskId?.S ?? null,
    status: item.status?.S ?? null,
    submittedAt: item.submittedAt?.S ?? null,
    updatedAt: item.updatedAt?.S ?? null,
    completedAt: item.completedAt?.S ?? null,
    payload: parsedPayload,
    result: parsedResult,
  };
}

function buildHeaders(origin = "*") {
  return {
    "content-type": "application/json",
    "access-control-allow-origin": origin,
    "access-control-allow-methods": "GET,POST,OPTIONS",
    "access-control-allow-headers": "authorization,content-type,x-requested-with",
  };
}

function response(statusCode, body, origin) {
  return {
    statusCode,
    headers: buildHeaders(origin),
    body: JSON.stringify(body),
  };
}

function parseJsonBody(rawBody) {
  if (!rawBody) {
    return {};
  }
  try {
    return JSON.parse(rawBody);
  } catch {
    return null;
  }
}

export async function handler(event) {
  const origin = event?.headers?.origin || "*";
  const routeKey = event?.requestContext?.routeKey || "";
  const method = event?.requestContext?.http?.method;

  if (method === "OPTIONS") {
    return response(200, { ok: true }, origin);
  }

  if (routeKey === "GET /health") {
    return response(
      200,
      {
        ok: true,
        service: "serverless-base-api",
        timestamp: new Date().toISOString(),
      },
      origin
    );
  }

  if (routeKey === "POST /tasks") {
    if (!tableName || !queueUrl) {
      return response(
        500,
        {
          error: "Lambda environment is missing MAIN_TABLE_NAME or TASK_QUEUE_URL.",
        },
        origin
      );
    }

    const payload = parseJsonBody(event.body);
    if (payload === null) {
      return response(400, { error: "Invalid JSON body." }, origin);
    }

    const taskId = crypto.randomUUID();
    const now = new Date().toISOString();
    const ttl = Math.floor(Date.now() / 1000) + 14 * 24 * 60 * 60;

    await dynamodb.send(
      new PutItemCommand({
        TableName: tableName,
        Item: {
          pk: toStringAttr(`TASK#${taskId}`),
          sk: toStringAttr(`TASK#${taskId}`),
          gsi1pk: toStringAttr("TASK_STATUS#QUEUED"),
          gsi1sk: toStringAttr(now),
          taskId: toStringAttr(taskId),
          status: toStringAttr("QUEUED"),
          submittedAt: toStringAttr(now),
          updatedAt: toStringAttr(now),
          payload: toJsonStringAttr(payload),
          result: toJsonStringAttr({ message: "Queued for processing." }),
          expiresAt: toNumberAttr(ttl),
        },
      })
    );

    await sqs.send(
      new SendMessageCommand({
        QueueUrl: queueUrl,
        MessageBody: JSON.stringify({
          taskId,
          input: payload,
          submittedAt: now,
        }),
      })
    );

    return response(202, { taskId, status: "QUEUED" }, origin);
  }

  if (routeKey === "GET /tasks/{taskId}") {
    if (!tableName) {
      return response(
        500,
        { error: "Lambda environment is missing MAIN_TABLE_NAME." },
        origin
      );
    }

    const taskId = event?.pathParameters?.taskId;
    if (!taskId) {
      return response(
        400,
        { error: "taskId path parameter is required." },
        origin
      );
    }

    const record = await dynamodb.send(
      new GetItemCommand({
        TableName: tableName,
        Key: {
          pk: toStringAttr(`TASK#${taskId}`),
          sk: toStringAttr(`TASK#${taskId}`),
        },
      })
    );

    if (!record.Item) {
      return response(404, { error: "Task not found." }, origin);
    }

    return response(200, { task: fromDynamoItem(record.Item) }, origin);
  }

  return response(404, { error: "Route not found." }, origin);
}
