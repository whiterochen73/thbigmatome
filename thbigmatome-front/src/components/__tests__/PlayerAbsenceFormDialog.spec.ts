import { beforeEach, describe, expect, it, vi } from 'vitest'
import { flushPromises, mount } from '@vue/test-utils'
import { defineComponent, nextTick } from 'vue'
import { createI18n } from 'vue-i18n'
import PlayerAbsenceFormDialog from '../PlayerAbsenceFormDialog.vue'
import type { PlayerAbsence } from '@/types/playerAbsence'

vi.mock('axios', () => ({
  default: {
    post: vi.fn(),
    put: vi.fn(),
    defaults: { baseURL: '', withCredentials: false, headers: { common: {} } },
    interceptors: { request: { use: vi.fn() }, response: { use: vi.fn() } },
  },
}))

const showSnackbar = vi.fn()
vi.mock('@/composables/useSnackbar', () => ({
  useSnackbar: () => ({ showSnackbar }),
}))

import axios from 'axios'

const i18n = createI18n({
  legacy: false,
  locale: 'ja',
  missingWarn: false,
  fallbackWarn: false,
  messages: { ja: {} },
})

const FormStub = defineComponent({
  name: 'VForm',
  setup(_, { slots, expose }) {
    expose({
      validate: vi.fn(async () => ({ valid: true })),
      resetValidation: vi.fn(),
    })
    return () => slots.default?.()
  },
})

const passThrough = (name: string) =>
  defineComponent({
    name,
    props: ['modelValue'],
    emits: ['update:modelValue'],
    setup(_, { slots }) {
      return () => slots.default?.()
    },
  })

const fieldStub = (name: string) =>
  defineComponent({
    name,
    props: ['modelValue'],
    emits: ['update:modelValue'],
    template:
      '<input :value="modelValue" @input="$emit(\'update:modelValue\', $event.target.value)" />',
  })

const baseAbsence: PlayerAbsence = {
  id: 12,
  team_membership_id: 7,
  player_id: 70,
  season_id: 3,
  absence_type: 'injury',
  reason: '検査',
  start_date: '2026-04-01',
  duration: 10,
  duration_unit: 'days',
  phase: 'pre_game',
  effective_start_date: '2026-04-01',
  effective_end_date: '2026-04-11',
  created_at: '',
  updated_at: '',
  player_name: '霊夢',
}

function mountDialog(props = {}) {
  return mount(PlayerAbsenceFormDialog, {
    props: {
      modelValue: true,
      teamId: 1,
      seasonId: 3,
      initialStartDate: '2026-04-05',
      ...props,
    },
    global: {
      plugins: [i18n],
      stubs: {
        VDialog: passThrough('VDialog'),
        VCard: passThrough('VCard'),
        VCardTitle: passThrough('VCardTitle'),
        VCardText: passThrough('VCardText'),
        VCardActions: passThrough('VCardActions'),
        VContainer: passThrough('VContainer'),
        VRow: passThrough('VRow'),
        VCol: passThrough('VCol'),
        VSpacer: true,
        VForm: FormStub,
        VTextField: fieldStub('VTextField'),
        VSelect: fieldStub('VSelect'),
        VBtn: passThrough('VBtn'),
        TeamMemberSelect: fieldStub('TeamMemberSelect'),
      },
    },
  })
}

describe('PlayerAbsenceFormDialog', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('新規登録はPOST /player_absences後にsaved emitとcloseを行う', async () => {
    vi.mocked(axios.post).mockResolvedValueOnce({ data: { id: 1 } })
    const wrapper = mountDialog()

    Object.assign(wrapper.vm.newAbsence, {
      team_membership_id: 7,
      reason: '検査',
      start_date: '2026-04-05',
      duration: 3,
      duration_unit: 'days',
    })
    await wrapper.vm.saveAbsence()

    expect(axios.post).toHaveBeenCalledWith(
      '/player_absences',
      expect.objectContaining({ season_id: 3, team_membership_id: 7, duration: 3 }),
    )
    expect(wrapper.emitted('saved')).toHaveLength(1)
    expect(wrapper.emitted('update:modelValue')?.at(-1)).toEqual([false])
  })

  it('編集時はinitialAbsenceを読み込みPUT /player_absences/:idを呼ぶ', async () => {
    vi.mocked(axios.put).mockResolvedValueOnce({ data: baseAbsence })
    const wrapper = mountDialog({ modelValue: false, initialAbsence: baseAbsence })

    await wrapper.setProps({ modelValue: true })
    await nextTick()
    expect(wrapper.vm.newAbsence.id).toBe(12)
    await wrapper.vm.saveAbsence()

    expect(axios.put).toHaveBeenCalledWith(
      '/player_absences/12',
      expect.objectContaining({ id: 12 }),
    )
    expect(wrapper.emitted('saved')).toHaveLength(1)
  })

  it('新規オープン時はinitialStartDateをstart_dateに反映する', async () => {
    const wrapper = mountDialog({ modelValue: false, initialStartDate: '2026-04-20' })

    await wrapper.setProps({ modelValue: true })
    await nextTick()

    expect(wrapper.vm.newAbsence.start_date).toBe('2026-04-20')
  })

  it('duration_unit days/gamesの差分を保存payloadに反映する', async () => {
    vi.mocked(axios.post).mockResolvedValue({ data: { id: 1 } })
    const wrapper = mountDialog()

    Object.assign(wrapper.vm.newAbsence, {
      team_membership_id: 7,
      reason: '検査',
      duration_unit: 'games',
    })
    await wrapper.vm.saveAbsence()
    expect(axios.post).toHaveBeenLastCalledWith(
      '/player_absences',
      expect.objectContaining({ duration_unit: 'games' }),
    )

    Object.assign(wrapper.vm.newAbsence, { duration_unit: 'days' })
    await wrapper.vm.saveAbsence()
    expect(axios.post).toHaveBeenLastCalledWith(
      '/player_absences',
      expect.objectContaining({ duration_unit: 'days' }),
    )
  })

  it('保存失敗時はsnackbar errorを表示しsaved emitしない', async () => {
    vi.mocked(axios.post).mockRejectedValueOnce(new Error('network'))
    const wrapper = mountDialog()

    await wrapper.vm.saveAbsence()
    await flushPromises()

    expect(showSnackbar).toHaveBeenCalledWith(
      'playerAbsenceDialog.notifications.saveFailed',
      'error',
    )
    expect(wrapper.emitted('saved')).toBeUndefined()
  })

  // 離脱の区分（試合前 / 試合中。裁定 AMB-25）
  describe('区分（phase）', () => {
    it('新規は既定で試合前。保存の payload に phase: pre_game が入る', async () => {
      vi.mocked(axios.post).mockResolvedValueOnce({ data: { id: 1 } })
      const wrapper = mountDialog()
      expect(wrapper.vm.newAbsence.phase).toBe('pre_game')

      Object.assign(wrapper.vm.newAbsence, { team_membership_id: 7, reason: '検査' })
      await wrapper.vm.saveAbsence()
      expect(axios.post).toHaveBeenCalledWith(
        '/player_absences',
        expect.objectContaining({ phase: 'pre_game' }),
      )
    })

    it('区分の選択肢は 試合前 / 試合中 の 2 つで、入力欄がダイアログに出る', () => {
      const wrapper = mountDialog()
      expect(wrapper.vm.phases).toEqual([
        { title: 'enums.player_absence.phase.pre_game', value: 'pre_game' },
        { title: 'enums.player_absence.phase.in_game', value: 'in_game' },
      ])
      expect(wrapper.find('[data-testid="absence-phase"]').exists()).toBe(true)
    })

    it('initialPhase=in_game を渡すと、新規オープン時の区分が試合中になり、payload に入る', async () => {
      vi.mocked(axios.post).mockResolvedValueOnce({ data: { id: 1 } })
      const wrapper = mountDialog({ modelValue: false, initialPhase: 'in_game' })
      await wrapper.setProps({ modelValue: true })
      await nextTick()
      expect(wrapper.vm.newAbsence.phase).toBe('in_game')

      Object.assign(wrapper.vm.newAbsence, { team_membership_id: 7, reason: '死球' })
      await wrapper.vm.saveAbsence()
      expect(axios.post).toHaveBeenCalledWith(
        '/player_absences',
        expect.objectContaining({ phase: 'in_game' }),
      )
    })

    it('開き直した新規登録は、前回選んだ区分を持ち越さず既定値に戻る', async () => {
      const wrapper = mountDialog({ modelValue: false, initialPhase: 'in_game' })
      await wrapper.setProps({ modelValue: true })
      await nextTick()
      wrapper.vm.newAbsence.phase = 'pre_game'
      await wrapper.setProps({ modelValue: false })
      await wrapper.setProps({ modelValue: true })
      await nextTick()
      expect(wrapper.vm.newAbsence.phase).toBe('in_game')
    })

    it('編集は離脱の区分を読み込む（initialPhase の既定値で上書きしない）。変更して PUT できる', async () => {
      vi.mocked(axios.put).mockResolvedValueOnce({ data: baseAbsence })
      const wrapper = mountDialog({
        modelValue: false,
        initialPhase: 'in_game',
        initialAbsence: baseAbsence,
      })
      await wrapper.setProps({ modelValue: true })
      await nextTick()
      expect(wrapper.vm.newAbsence.phase).toBe('pre_game')

      wrapper.vm.newAbsence.phase = 'in_game'
      await wrapper.vm.saveAbsence()
      expect(axios.put).toHaveBeenCalledWith(
        '/player_absences/12',
        expect.objectContaining({ id: 12, phase: 'in_game' }),
      )
    })

    it('区分に応じた説明（数え始め）を出す', async () => {
      const wrapper = mountDialog({ initialPhase: 'in_game' })
      await wrapper.setProps({ modelValue: false })
      await wrapper.setProps({ modelValue: true })
      await nextTick()
      expect(wrapper.vm.phaseHint).toBe('playerAbsenceDialog.form.phaseHint.in_game')
      wrapper.vm.newAbsence.phase = 'pre_game'
      await nextTick()
      expect(wrapper.vm.phaseHint).toBe('playerAbsenceDialog.form.phaseHint.pre_game')
    })
  })
})
