import {setGlobalOptions} from "firebase-functions";
import {HttpsError, onCall} from "firebase-functions/https";
import * as logger from "firebase-functions/logger";
import {initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";

initializeApp();

setGlobalOptions({maxInstances: 10});

export const deleteAccount = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "You must be signed in to delete your account."
    );
  }

  const uid = request.auth.uid;
  await getAuth().deleteUser(uid);
  logger.info("Deleted account", {uid});

  return {success: true};
});
