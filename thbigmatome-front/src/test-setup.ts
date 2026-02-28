// Test setup for Vitest
// Mock visualViewport which is not available in happy-dom
if (!window.visualViewport) {
  Object.defineProperty(window, 'visualViewport', {
    value: {
      width: 1024,
      height: 768,
      scale: 1,
      offsetLeft: 0,
      offsetTop: 0,
      pageLeft: 0,
      pageTop: 0,
      addEventListener: () => {},
      removeEventListener: () => {},
    },
    writable: true,
  })
}
