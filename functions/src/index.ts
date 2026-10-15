import {setGlobalOptions} from "firebase-functions";
import {HttpsError, onCall} from "firebase-functions/https";
import {
  onDocumentCreated,
  onDocumentDeleted,
} from "firebase-functions/firestore";
import * as logger from "firebase-functions/logger";
import {initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {FieldValue, getFirestore} from "firebase-admin/firestore";

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

export const onCommentCreated = onDocumentCreated(
  "posts/{postId}/comments/{commentId}",
  async (event) => {
    const postId = event.params.postId;
    await getFirestore()
      .doc(`posts/${postId}`)
      .update({comments_count: FieldValue.increment(1)});
    logger.info("Incremented comments_count", {postId});
  }
);

export const onCommentDeleted = onDocumentDeleted(
  "posts/{postId}/comments/{commentId}",
  async (event) => {
    const postId = event.params.postId;
    await getFirestore()
      .doc(`posts/${postId}`)
      .update({comments_count: FieldValue.increment(-1)});
    logger.info("Decremented comments_count", {postId});
  }
);
