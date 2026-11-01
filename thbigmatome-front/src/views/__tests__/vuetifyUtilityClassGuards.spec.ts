import { readdirSync, readFileSync } from 'node:fs'
import { relative, resolve, sep } from 'node:path'
import { expect, it } from 'vitest'

const srcDir = resolve(process.cwd(), 'src')

function vueFiles(dir: string): string[] {
  return readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    if (entry.name === '__tests__') return []
    const path = resolve(dir, entry.name)
    if (entry.isDirectory()) return vueFiles(path)
    return entry.name.endsWith('.vue') ? [path] : []
  })
}

// Test Basis: subtask_1804b の warning。Vuetify のユーティリティに `ga-x-2` / `ga-y-2` は無く、
// 書いても何も起きない（隙間が付かず、記号と文字が詰まる）。隙間は ga-N（縦横）・gc-N（横）・gr-N（縦）。
it('Vuetify に無い隙間のクラス（ga-x-N / ga-y-N）を使わない', () => {
  const violations = vueFiles(srcDir).flatMap((file) => {
    const lines = readFileSync(file, 'utf8').split('\n')
    const path = relative(srcDir, file).split(sep).join('/')
    return lines.flatMap((line, i) => (/\bga-[xy]-\d/.test(line) ? [`${path}:${i + 1}`] : []))
  })
  expect(violations).toEqual([])
})
