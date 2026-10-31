import { readdirSync, readFileSync } from 'node:fs'
import { relative, resolve, sep } from 'node:path'
import { expect, it } from 'vitest'

const srcDir = resolve(process.cwd(), 'src')
const materialName =
  '(?:red|pink|purple|deep-purple|indigo|blue|light-blue|cyan|teal|green|light-green|lime|yellow|amber|orange|deep-orange|brown|grey|blue-grey)'
const colorLiteral = new RegExp(`['"]${materialName}(?:-(?:lighten|darken|accent)-\\d+)?['"]`, 'g')
const materialClass = new RegExp(
  `\\b(?:text|bg|border)-${materialName}(?:-(?:lighten|darken|accent)-\\d+)?(?![\\w-])`,
  'g',
)

function sourceFiles(dir: string): string[] {
  return readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    if (entry.name === '__tests__') return []
    const path = resolve(dir, entry.name)
    if (entry.isDirectory()) return sourceFiles(path)
    return /\.(?:vue|ts)$/.test(entry.name) ? [path] : []
  })
}

// Test Basis: thbig-dugout-visual-stage5-mapping.md §7 b0-5, b8-1〜b11-29 / Q1
it('keeps Material color names only in the permanent BattingTable allowance', () => {
  const allowed: Record<string, { count: number; batch: string }> = {
    'components/BattingTable.vue': { count: 20, batch: 'Q1 permanent allowance: batting outcomes' },
  }
  const violations: string[] = []

  for (const file of sourceFiles(srcDir)) {
    const source = readFileSync(file, 'utf8')
    const path = relative(srcDir, file).split(sep).join('/')
    const matches = [...source.matchAll(colorLiteral), ...source.matchAll(materialClass)]
    const limit = allowed[path]?.count ?? 0
    if (matches.length > limit) {
      violations.push(`${path}: ${matches.length} > ${limit}`)
    }
  }
  expect(violations).toEqual([])
})
