import { beforeEach, describe, expect, it, vi } from 'vitest'
import { flushPromises, mount } from '@vue/test-utils'
import { createI18n } from 'vue-i18n'
import PlayerDialog from '../PlayerDialog.vue'
import type { PlayerDetail } from '@/types/playerDetail'

vi.mock('@/plugins/axios', () => ({
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

import axios from '@/plugins/axios'

const i18n = createI18n({
  legacy: false,
  locale: 'ja',
  missingWarn: false,
  fallbackWarn: false,
  messages: {
    ja: {
      actions: { cancel: 'キャンセル', save: '保存' },
      playerDialog: {
        title: { add: '選手追加', edit: '選手編集' },
        notifications: {
          addSuccess: '追加成功',
          updateSuccess: '更新成功',
          saveFailed: '保存失敗',
          saveFailedWithErrors: '保存失敗: {errors}',
        },
      },
    },
  },
})

const passThrough = { template: '<div><slot /></div>' }
const item: PlayerDetail = { id: 10, name: '霊夢', number: '1', short_name: '霊夢' }

function mountDialog(props = {}) {
  return mount(PlayerDialog, {
    props: { modelValue: true, item: null, ...props },
    global: {
      plugins: [i18n],
      stubs: {
        VDialog: passThrough,
        VCard: passThrough,
        VCardTitle: passThrough,
        VCardText: passThrough,
        VCardActions: passThrough,
        VSpacer: true,
        VBtn: passThrough,
        VDivider: true,
        PlayerIdentityForm: true,
      },
    },
  })
}

describe('PlayerDialog', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('item=nullで新規POST /playersを呼びsave emitする', async () => {
    vi.mocked(axios.post).mockResolvedValueOnce({ data: { id: 1 } })
    const wrapper = mountDialog()
    wrapper.vm.editableItem.name = '魔理沙'

    await wrapper.vm.saveItem()

    expect(axios.post).toHaveBeenCalledWith('/players', {
      player: expect.objectContaining({ name: '魔理沙' }),
    })
    expect(showSnackbar).toHaveBeenCalledWith('追加成功', 'success')
    expect(wrapper.emitted('save')).toHaveLength(1)
    expect(wrapper.emitted('update:modelValue')?.at(-1)).toEqual([false])
  })

  it('itemありで編集PUT /players/:idを呼ぶ', async () => {
    vi.mocked(axios.put).mockResolvedValueOnce({ data: item })
    const wrapper = mountDialog({ item })
    await wrapper.setProps({ modelValue: false })
    await wrapper.setProps({ modelValue: true })
    wrapper.vm.editableItem.name = '博麗霊夢'

    await wrapper.vm.saveItem()

    expect(axios.put).toHaveBeenCalledWith('/players/10', {
      player: expect.objectContaining({ name: '博麗霊夢' }),
    })
    expect(showSnackbar).toHaveBeenCalledWith('更新成功', 'success')
  })

  it('名前が空なら保存しない', async () => {
    const wrapper = mountDialog()
    wrapper.vm.editableItem.name = ''

    await wrapper.vm.saveItem()

    expect(axios.post).not.toHaveBeenCalled()
    expect(wrapper.emitted('save')).toBeUndefined()
  })

  it('保存失敗時はerror snackbarを表示する', async () => {
    vi.mocked(axios.post).mockRejectedValueOnce(new Error('network'))
    const wrapper = mountDialog()
    wrapper.vm.editableItem.name = '咲夜'

    await wrapper.vm.saveItem()
    await flushPromises()

    expect(showSnackbar).toHaveBeenCalledWith('保存失敗', 'error')
    expect(wrapper.emitted('save')).toBeUndefined()
  })
})
