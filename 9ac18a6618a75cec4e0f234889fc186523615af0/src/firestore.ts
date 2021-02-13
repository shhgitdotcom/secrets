import firebase from "firebase/app";

export const config = {
  databaseURL: "",
  apiKey: "AIzaSyBA3jRug5NJGdtkCA4oYfFVRHOZvKY6TEg",
  authDomain: "week-budget.firebaseapp.com",
  projectId: "week-budget",
  storageBucket: "week-budget.appspot.com",
  messagingSenderId: "1005237651444",
  appId: "1:1005237651444:web:9f04db6dccd83c555471e9",
  measurementId: "G-2S8WVRFZBF",
};

export default firebase.initializeApp(config);
