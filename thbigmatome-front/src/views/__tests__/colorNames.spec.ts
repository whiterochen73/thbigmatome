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

// Test Basis: thbig-dugout-visual-stage5-mapping.md §7 b0-5, b1-1〜b4-26 / subtask_1787o 申し送り1〜2
it('keeps Material color names within the remaining batch allowance', () => {
  // Counts are the remaining matches after batch 4. Later batches reduce them.
  const allowed: Record<string, { count: number; batch: string }> = {
    'components/AtBatCard.vue': { count: 28, batch: 'b8, b10' },
    // b10 removes one text-grey; Q1 permits the other 20 batting outcome colors.
    'components/BattingTable.vue': { count: 21, batch: 'b10 (1), Q1 allowed (20)' },
    'components/commissioner/CommissionerDashboard.vue': { count: 6, batch: 'b2, b5' },
    'components/commissioner/RosterStatusTab.vue': { count: 5, batch: 'b5' },
    'components/EmptyState.vue': { count: 1, batch: 'b10' },
    'components/pitcher/PitcherAppearanceTab.vue': { count: 4, batch: 'b10' },
    'components/pitcher/PitcherRoleStateCell.vue': { count: 1, batch: 'b4, b10' },
    'components/pitcher/PitcherStatusTab.vue': { count: 4, batch: 'b10, b11' },
    'components/PlayerCardItem.vue': { count: 9, batch: 'b5, b10' },
    'components/settings/BattingSkillDialog.vue': { count: 3, batch: 'b7' },
    'components/settings/BattingSkillSettings.vue': { count: 3, batch: 'b7' },
    'components/settings/PitchingSkillDialog.vue': { count: 3, batch: 'b7' },
    'components/settings/PitchingSkillSettings.vue': { count: 3, batch: 'b7' },
    'components/settings/ScheduleDetailEditor.vue': { count: 7, batch: 'b7' },
    'components/shared/PlayerNameLink.vue': { count: 3, batch: 'b11' },
    'components/shared/StatusChip.vue': { count: 1, batch: 'b5' },
    'views/CostAssignment.vue': { count: 1, batch: 'b5' },
    'views/GameDetailView.vue': { count: 6, batch: 'b6, b11' },
    'views/GameLineupView.vue': { count: 5, batch: 'b11' },
    'views/GameRecordDetailView.vue': { count: 5, batch: 'b11' },
    'views/GameRecordListView.vue': { count: 1, batch: 'b11' },
    'views/GamesView.vue': { count: 1, batch: 'b11' },
    'views/ManagerList.vue': { count: 2, batch: 'b2, b5, b11' },
    'views/PlayerCardDetailView.vue': { count: 3, batch: 'b5, b6, b11' },
    'views/PlayerCardsView.vue': { count: 2, batch: 'b5' },
    'views/PlayerDetailView.vue': { count: 2, batch: 'b9, b11' },
    'views/Players.vue': { count: 1, batch: 'b2, b11' },
    'views/TeamList.vue': { count: 1, batch: 'b2, b5' },
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
