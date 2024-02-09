// import from utils example
import { minus } from "/opt/nodejs/services/test";
import { add } from "/opt/nodejs/utils/test";

import { APIGatewayEvent, Handler } from "aws-lambda";

export const handler: Handler = async (event: APIGatewayEvent, context) => {
  console.log("EVENT: \n" + JSON.stringify(event, null, 2));
  console.log(`Expect add result "${add(1, 2)}" to be 3`);
  console.log(`Expect minus result "${minus(1, 2)}" to be -1`);

  return {
    statusCode: 200,
    body: JSON.stringify({
      message: "Hello from get-demo!",
      queryParameters: event.queryStringParameters || {},
      pathParameters: event.pathParameters || {},
      minus: minus(1, 2),
      add: add(1, 2),
    }),
  };
};
