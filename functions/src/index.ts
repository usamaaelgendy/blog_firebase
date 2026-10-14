import {setGlobalOptions} from "firebase-functions";
import {onRequest} from "firebase-functions/https";
import * as logger from "firebase-functions/logger";

setGlobalOptions({maxInstances: 10});

export const helloWorld = onRequest((request, response) => {
  const name = request.query.name ?? "Flutter";

  logger.info("Hello logs!", {structuredData: true});
  response.send(`Hello ${name} From Cloud Functions`);
});
