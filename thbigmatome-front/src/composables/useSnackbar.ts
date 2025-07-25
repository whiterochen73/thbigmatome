import { ref, readonly } from 'vue';

// Snackbarの状態をグローバルで管理するためのリアクティブな変数
const isVisible = ref(false);
const message = ref('');
const color = ref<'success' | 'error' | 'info' | 'warning'>('info');
const timeout = ref(3000);
let timeoutId: number | undefined;

/**
 * アプリケーション全体で共有されるSnackbarを管理するコンポーザブル
 */
export function useSnackbar() {
  /**
   * Snackbarを表示する
   * @param text 表示するメッセージ
   * @param snackbarColor Snackbarの色
   */
  const showSnackbar = (text: string, snackbarColor: 'success' | 'error' | 'info' | 'warning' = 'info') => {
    message.value = text;
    color.value = snackbarColor;
    isVisible.value = true;

    // 既存のタイマーがあればクリア
    if (timeoutId) {
      clearTimeout(timeoutId);
    }

    // 新しいタイマーをセット
    timeoutId = window.setTimeout(() => {
      isVisible.value = false;
      timeoutId = undefined;
    }, timeout.value);
  };

  return {
    isVisible: readonly(isVisible),
    message: readonly(message),
    color: readonly(color),
    timeout: readonly(timeout),
    showSnackbar,
  };
}