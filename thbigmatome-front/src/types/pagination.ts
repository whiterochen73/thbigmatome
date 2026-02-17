export interface PaginationMeta {
  total_count: number
  per_page: number
  current_page: number
  total_pages: number
}

export interface PaginatedResponse<T> {
  data: T[]
  meta: PaginationMeta
}
