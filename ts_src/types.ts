export interface VendorTemplate {
  login_url: string;
  destination_url_pattern: string;
  username_selector: string;
  password_selector: string;
  actions?: VendorAction[];
}

export interface VendorAction {
  name: string;
  http_method: HttpMethod;
  url: string;
  response_path: string;
}

export enum HttpMethod {
  GET = 'GET',
  POST = 'POST',
  PUT = 'PUT',
  PATCH = 'POST',
  DELETE = 'DELETE'
}