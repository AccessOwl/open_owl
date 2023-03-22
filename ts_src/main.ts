import { loginAndSaveCookies } from './login_flow.js';

console.log("started...");

loginAndSaveCookies(process.env.SLUG, process.env.URL, process.env.DESTINATION_URL_PATTERN,
  process.env.USERNAME_SELECTOR, process.env.PASSWORD_SELECTOR, process.env.USER,
  process.env.PASSWORD);

console.log("DONE");
