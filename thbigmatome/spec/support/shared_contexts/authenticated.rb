RSpec.shared_context 'authenticated user' do
  let(:user) { create(:user) }

  before do
    post '/api/v1/auth/login', params: { name: user.name, password: 'password123' }, as: :json
  end
end

RSpec.shared_context 'authenticated commissioner' do
  let(:user) { create(:user, :commissioner) }

  before do
    post '/api/v1/auth/login', params: { name: user.name, password: 'password123' }, as: :json
  end
end
