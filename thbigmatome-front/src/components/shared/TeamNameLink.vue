<template>
  <a class="team-name-link" :href="href" @click.stop="onClick"
    ><slot>{{ name }}</slot></a
  >
</template>

<script setup lang="ts">
import { computed } from 'vue'

// チーム名を押せるようにする部品。a 要素なので Tab で辿れて Enter で開く。
// 移動そのものは呼び出し側が行う（他チームへ移る時は選択中チームの切り替え teamSelectionStore.selectTeam も一緒に行うため）。
// 修飾キー付き・中クリックはブラウザに任せ、新しいタブで開けるようにする。
const props = defineProps<{
  teamId: number
  name: string
  /** 飛び先（アプリ内のパス）。既定はそのチームのシーズン画面（カレンダー） */
  to?: string
}>()

const emit = defineEmits<{ open: [team: { id: number; name: string }] }>()

const path = computed(() => props.to ?? `/teams/${props.teamId}/season`)
// アプリを basePath 配下で配信しても href が正しいよう、router の base と同じ BASE_URL を前に付ける
const href = computed(() => `${import.meta.env.BASE_URL.replace(/\/$/, '')}${path.value}`)

const onClick = (event: MouseEvent) => {
  if (event.button !== 0 || event.ctrlKey || event.metaKey || event.shiftKey || event.altKey) return
  event.preventDefault()
  emit('open', { id: props.teamId, name: props.name })
}
</script>

<style scoped>
.team-name-link {
  color: rgb(var(--v-theme-link));
  cursor: pointer;
  text-decoration: underline;
  text-decoration-thickness: 1px;
  text-underline-offset: 0.2em;
}

.team-name-link:hover {
  text-decoration-thickness: 2px;
}

.team-name-link:focus-visible {
  outline: 2px solid rgb(var(--v-theme-link));
  outline-offset: 2px;
  border-radius: 2px;
}
</style>
