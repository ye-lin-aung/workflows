Rails.application.routes.draw do
  mount Workflows::Engine => "/workflows"
end
