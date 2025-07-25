// src/plugins/axios.ts
import axios, { AxiosError, type AxiosResponse } from 'axios';
import router from '@/router';

axios.defaults.baseURL = 'http://localhost:3000/api/v1';
axios.defaults.withCredentials = true;

// レスポンスインターセプター
axios.interceptors.response.use(
  (response: AxiosResponse) => {
    // レスポンスヘッダーからCSRFトークンを確実に取得するロジック
    const csrfToken = response.headers['x-csrf-token'] || response.headers['X-CSRF-Token'] || response.headers['X-Csrf-Token'];

    if (csrfToken) {
      axios.defaults.headers.common['X-CSRF-Token'] = csrfToken;
    }
    return response;
  },
  (error: AxiosError) => {
    console.error('Axios plugin: Response interceptor error.', error.config?.url, error.response?.status);
    if (error.response?.status === 401) {
      console.warn('Authentication error (401). Redirecting to login page.');
      router.push('/login');
    } else if (error.response?.status === 403) {
      console.warn('Authorization error (403). Access denied.');
    }
    return Promise.reject(error);
  }
);

export default axios;