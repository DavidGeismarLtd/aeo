module ApplicationHelper
  # Returns the current workspace for the signed-in user
  # Uses ActsAsTenant.current_tenant which is set in ApplicationController
  def current_workspace
    ActsAsTenant.current_tenant
  end

  def flash_class(level)
    case level.to_sym
    when :notice then "bg-blue-100 border-blue-400 text-blue-700"
    when :success then "bg-green-100 border-green-400 text-green-700"
    when :error then "bg-red-100 border-red-400 text-red-700"
    when :alert then "bg-yellow-100 border-yellow-400 text-yellow-700"
    else "bg-gray-100 border-gray-400 text-gray-700"
    end
  end

  def active_link_class(path)
    current_page?(path) ? "bg-indigo-50 text-indigo-600" : "text-gray-700 hover:bg-gray-50"
  end

  def user_avatar(user, size: "md")
    size_classes = {
      "sm" => "h-8 w-8 text-sm",
      "md" => "h-10 w-10 text-base",
      "lg" => "h-12 w-12 text-lg",
      "xl" => "h-16 w-16 text-xl"
    }

    content_tag :div, class: "#{size_classes[size]} rounded-full bg-indigo-600 flex items-center justify-center text-white font-semibold" do
      user.initials
    end
  end
end
