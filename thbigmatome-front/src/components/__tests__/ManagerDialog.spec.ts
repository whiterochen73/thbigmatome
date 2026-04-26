import { beforeEach, describe, expect, it, vi } from 'vitest'
import { mount } from '@vue/test-utils'
import { createI18n } from 'vue-i18n'
import ManagerDialog from '../ManagerDialog.vue'
import type { Manager } from '@/types/manager'

vi.mock('@/plugins/axios', () => ({
  default: {
    post: vi.fn(),
    patch: vi.fn(),
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
      managerDialog: {
        title: { add: '監督追加', edit: '監督編集' },
        form: { name: '名前', shortName: '略称', ircName: 'IRC名', userId: 'ユーザーID' },
        validation: { required: '必須です' },
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
const fieldStub = { props: ['modelValue'], emits: ['update:modelValue'], template: '<input />' }
const manager: Manager = {
  id: 5,
  name: '監督A',
  short_name: 'A',
  irc_name: 'irc-a',
  user_id: 'user-a',
  role: 'director',
}

function mountDialog(props = {}) {
  return mount(ManagerDialog, {
    props: { isVisible: true, manager: null, ...props },
    global: {
      plugins: [i18n],
      stubs: {
        VDialog: passThrough,
        VCard: passThrough,
        VCardTitle: passThrough,
        VCardText: passThrough,
        VCardActions: passThrough,
        VContainer: passThrough,
        VRow: passThrough,
        VCol: passThrough,
        VSpacer: true,
        VTextField: fieldStub,
        VBtn: passThrough,
      },
    },
  })
}

describe('ManagerDialog', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('defineModel isVisibleのcloseでupdate:isVisible=falseをemitする', () => {
    const wrapper = mountDialog()

    wrapper.vm.close()

    expect(wrapper.emitted('update:isVisible')?.at(-1)).toEqual([false])
  })

  it('新規作成はPOST /managersを呼びsave emitする', async () => {
    vi.mocked(axios.post).mockResolvedValueOnce({ data: { id: 1 } })
    const wrapper = mountDialog()
    wrapper.vm.editedManager.name = '新監督'

    await wrapper.vm.save()

    expect(axios.post).toHaveBeenCalledWith('/managers', {
      manager: expect.objectContaining({ name: '新監督' }),
    })
    expect(showSnackbar).toHaveBeenCalledWith('追加成功', 'success')
    expect(wrapper.emitted('save')).toHaveLength(1)
  })

  it('編集はPATCH /managers/:idを呼ぶ', async () => {
    vi.mocked(axios.patch).mockResolvedValueOnce({ data: manager })
    const wrapper = mountDialog({ isVisible: false, manager })
    await wrapper.setProps({ isVisible: true })

    await wrapper.vm.save()

    expect(axios.patch).toHaveBeenCalledWith('/managers/5', {
      manager: expect.objectContaining({ id: 5 }),
    })
    expect(showSnackbar).toHaveBeenCalledWith('更新成功', 'success')
  })

  it('名前が空なら保存しない', async () => {
    const wrapper = mountDialog()
    wrapper.vm.editedManager.name = ''

    await wrapper.vm.save()

    expect(axios.post).not.toHaveBeenCalled()
    expect(wrapper.emitted('save')).toBeUndefined()
  })

  it('保存失敗時はerror snackbarを表示する', async () => {
    vi.mocked(axios.post).mockRejectedValueOnce(new Error('network'))
    const wrapper = mountDialog()
    wrapper.vm.editedManager.name = '新監督'

    await wrapper.vm.save()

    expect(showSnackbar).toHaveBeenCalledWith('保存失敗', 'error')
  })
})
