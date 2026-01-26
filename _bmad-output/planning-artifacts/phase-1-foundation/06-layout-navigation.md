# Task 06: Application Layout & Navigation

## Overview
**Estimated Time:** 6 hours  
**Dependencies:** Task 05 (Authentication)  
**Goal:** Create a beautiful, responsive application layout with navigation, workspace switcher, and interactive components using Tailwind CSS and Stimulus.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                         Navbar                               │
│  [Logo] [Workspace ▼]              [User Menu ▼] [Sign Out] │
└─────────────────────────────────────────────────────────────┘
┌──────────┬──────────────────────────────────────────────────┐
│          │                                                   │
│ Sidebar  │              Main Content Area                   │
│          │                                                   │
│ - Home   │  ┌─────────────────────────────────────────┐    │
│ - Tasks  │  │      Flash Messages (auto-dismiss)       │    │
│ - Team   │  └─────────────────────────────────────────┘    │
│ - Files  │                                                   │
│          │              <%= yield %>                        │
│          │                                                   │
│          │                                                   │
└──────────┴──────────────────────────────────────────────────┘
```

## Step-by-Step Implementation

### Step 1: Update Application Layout (30 minutes)

Create the main application layout with Tailwind CSS:

**File: `app/views/layouts/application.html.erb`**

```erb
<!DOCTYPE html>
<html class="h-full bg-gray-50">
  <head>
    <title><%= content_for(:title) || "AEO - Workspace Management" %></title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>

    <%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>
    <%= javascript_importmap_tags %>
  </head>

  <body class="h-full">
    <% if user_signed_in? %>
      <div class="min-h-full">
        <%= render "shared/navbar" %>
        
        <div class="flex h-[calc(100vh-4rem)]">
          <%= render "shared/sidebar" %>
          
          <main class="flex-1 overflow-y-auto bg-gray-50">
            <%= render "shared/flash_messages" %>
            
            <div class="py-6">
              <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
                <%= yield %>
              </div>
            </div>
          </main>
        </div>
      </div>
    <% else %>
      <!-- Public/Auth Pages Layout -->
      <div class="min-h-full bg-gray-50">
        <%= render "shared/flash_messages" %>
        <%= yield %>
      </div>
    <% end %>
  </body>
</html>
```

### Step 2: Create Responsive Navbar (1 hour)

Build a navbar with workspace switcher and user menu:

**File: `app/views/shared/_navbar.html.erb`**

```erb
<nav class="bg-white shadow-sm border-b border-gray-200">
  <div class="mx-auto px-4 sm:px-6 lg:px-8">
    <div class="flex h-16 justify-between items-center">
      <!-- Left: Logo and Workspace Switcher -->
      <div class="flex items-center space-x-4">
        <!-- Logo -->
        <%= link_to root_path, class: "flex items-center" do %>
          <span class="text-2xl font-bold text-indigo-600">AEO</span>
        <% end %>
        
        <!-- Workspace Switcher -->
        <% if current_workspace.present? %>
          <div class="relative" data-controller="dropdown">
            <button type="button" 
                    data-action="click->dropdown#toggle"
                    class="flex items-center space-x-2 rounded-md border border-gray-300 bg-white px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2">
              <span><%= current_workspace.name %></span>
              <svg class="h-5 w-5 text-gray-400" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                <path fill-rule="evenodd" d="M5.23 7.21a.75.75 0 011.06.02L10 11.168l3.71-3.938a.75.75 0 111.08 1.04l-4.25 4.5a.75.75 0 01-1.08 0l-4.25-4.5a.75.75 0 01.02-1.06z" clip-rule="evenodd" />
              </svg>
            </button>
            
            <!-- Dropdown Menu -->
            <div data-dropdown-target="menu"
                 class="hidden absolute left-0 z-10 mt-2 w-64 origin-top-left rounded-md bg-white shadow-lg ring-1 ring-black ring-opacity-5 focus:outline-none">
              <div class="py-1">
                <div class="px-4 py-2 text-xs font-semibold text-gray-500 uppercase tracking-wide">
                  Your Workspaces
                </div>
                <% current_user.workspaces.each do |workspace| %>
                  <%= link_to workspace_path(workspace),
                      class: "block px-4 py-2 text-sm text-gray-700 hover:bg-gray-100 #{workspace == current_workspace ? 'bg-indigo-50 text-indigo-600' : ''}" do %>
                    <div class="flex items-center justify-between">
                      <span class="font-medium"><%= workspace.name %></span>
                      <% if workspace == current_workspace %>
                        <svg class="h-5 w-5 text-indigo-600" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                          <path fill-rule="evenodd" d="M16.704 4.153a.75.75 0 01.143 1.052l-8 10.5a.75.75 0 01-1.127.075l-4.5-4.5a.75.75 0 011.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 011.05-.143z" clip-rule="evenodd" />
                        </svg>
                      <% end %>
                    </div>
                  <% end %>
                <% end %>
                <div class="border-t border-gray-100"></div>
                <%= link_to new_workspace_path,
                    class: "block px-4 py-2 text-sm text-indigo-600 hover:bg-gray-100 font-medium" do %>
                  <div class="flex items-center space-x-2">
                    <svg class="h-5 w-5" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                      <path d="M10.75 4.75a.75.75 0 00-1.5 0v4.5h-4.5a.75.75 0 000 1.5h4.5v4.5a.75.75 0 001.5 0v-4.5h4.5a.75.75 0 000-1.5h-4.5v-4.5z" />
                    </svg>
                    <span>Create New Workspace</span>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        <% end %>
      </div>

      <!-- Right: User Menu -->
      <div class="flex items-center space-x-4">
        <!-- Notifications (placeholder) -->
        <button type="button" class="rounded-full bg-white p-1 text-gray-400 hover:text-gray-500 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2">
          <span class="sr-only">View notifications</span>
          <svg class="h-6 w-6" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" d="M14.857 17.082a23.848 23.848 0 005.454-1.31A8.967 8.967 0 0118 9.75v-.7V9A6 6 0 006 9v.75a8.967 8.967 0 01-2.312 6.022c1.733.64 3.56 1.085 5.455 1.31m5.714 0a24.255 24.255 0 01-5.714 0m5.714 0a3 3 0 11-5.714 0" />
          </svg>
        </button>

        <!-- User Dropdown -->
        <div class="relative" data-controller="dropdown">
          <button type="button"
                  data-action="click->dropdown#toggle"
                  class="flex items-center space-x-3 rounded-full bg-white text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2">
            <span class="sr-only">Open user menu</span>
            <div class="h-8 w-8 rounded-full bg-indigo-600 flex items-center justify-center text-white font-medium">
              <%= current_user.email[0].upcase %>
            </div>
            <span class="hidden md:block text-sm font-medium text-gray-700"><%= current_user.email %></span>
            <svg class="hidden md:block h-5 w-5 text-gray-400" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
              <path fill-rule="evenodd" d="M5.23 7.21a.75.75 0 011.06.02L10 11.168l3.71-3.938a.75.75 0 111.08 1.04l-4.25 4.5a.75.75 0 01-1.08 0l-4.25-4.5a.75.75 0 01.02-1.06z" clip-rule="evenodd" />
            </svg>
          </button>

          <!-- User Dropdown Menu -->
          <div data-dropdown-target="menu"
               class="hidden absolute right-0 z-10 mt-2 w-56 origin-top-right rounded-md bg-white shadow-lg ring-1 ring-black ring-opacity-5 focus:outline-none">
            <div class="py-1">
              <div class="px-4 py-2 text-xs text-gray-500">
                Signed in as<br>
                <span class="font-medium text-gray-900"><%= current_user.email %></span>
              </div>
              <div class="border-t border-gray-100"></div>
              <%= link_to edit_user_registration_path, class: "block px-4 py-2 text-sm text-gray-700 hover:bg-gray-100" do %>
                <div class="flex items-center space-x-2">
                  <svg class="h-5 w-5 text-gray-400" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                    <path d="M10 8a3 3 0 100-6 3 3 0 000 6zM3.465 14.493a1.23 1.23 0 00.41 1.412A9.957 9.957 0 0010 18c2.31 0 4.438-.784 6.131-2.1.43-.333.604-.903.408-1.41a7.002 7.002 0 00-13.074.003z" />
                  </svg>
                  <span>Your Profile</span>
                </div>
              <% end %>
              <%= link_to "#", class: "block px-4 py-2 text-sm text-gray-700 hover:bg-gray-100" do %>
                <div class="flex items-center space-x-2">
                  <svg class="h-5 w-5 text-gray-400" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                    <path fill-rule="evenodd" d="M7.84 1.804A1 1 0 018.82 1h2.36a1 1 0 01.98.804l.331 1.652a6.993 6.993 0 011.929 1.115l1.598-.54a1 1 0 011.186.447l1.18 2.044a1 1 0 01-.205 1.251l-1.267 1.113a7.047 7.047 0 010 2.228l1.267 1.113a1 1 0 01.206 1.25l-1.18 2.045a1 1 0 01-1.187.447l-1.598-.54a6.993 6.993 0 01-1.929 1.115l-.33 1.652a1 1 0 01-.98.804H8.82a1 1 0 01-.98-.804l-.331-1.652a6.993 6.993 0 01-1.929-1.115l-1.598.54a1 1 0 01-1.186-.447l-1.18-2.044a1 1 0 01.205-1.251l1.267-1.114a7.05 7.05 0 010-2.227L1.821 7.773a1 1 0 01-.206-1.25l1.18-2.045a1 1 0 011.187-.447l1.598.54A6.993 6.993 0 017.51 3.456l.33-1.652zM10 13a3 3 0 100-6 3 3 0 000 6z" clip-rule="evenodd" />
                  </svg>
                  <span>Settings</span>
                </div>
              <% end %>
              <div class="border-t border-gray-100"></div>
              <%= button_to destroy_user_session_path, method: :delete, class: "w-full text-left px-4 py-2 text-sm text-red-700 hover:bg-red-50" do %>
                <div class="flex items-center space-x-2">
                  <svg class="h-5 w-5 text-red-400" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                    <path fill-rule="evenodd" d="M3 4.25A2.25 2.25 0 015.25 2h5.5A2.25 2.25 0 0113 4.25v2a.75.75 0 01-1.5 0v-2a.75.75 0 00-.75-.75h-5.5a.75.75 0 00-.75.75v11.5c0 .414.336.75.75.75h5.5a.75.75 0 00.75-.75v-2a.75.75 0 011.5 0v2A2.25 2.25 0 0110.75 18h-5.5A2.25 2.25 0 013 15.75V4.25z" clip-rule="evenodd" />
                    <path fill-rule="evenodd" d="M19 10a.75.75 0 00-.75-.75H8.704l1.048-.943a.75.75 0 10-1.004-1.114l-2.5 2.25a.75.75 0 000 1.114l2.5 2.25a.75.75 0 101.004-1.114l-1.048-.943h9.546A.75.75 0 0019 10z" clip-rule="evenodd" />
                  </svg>
                  <span>Sign Out</span>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</nav>
```

### Step 3: Create Sidebar Navigation (45 minutes)

Build a responsive sidebar with navigation links:

**File: `app/views/shared/_sidebar.html.erb`**

```erb
<!-- Mobile sidebar toggle -->
<div class="lg:hidden fixed bottom-4 right-4 z-50">
  <button type="button"
          data-controller="sidebar"
          data-action="click->sidebar#toggle"
          class="rounded-full bg-indigo-600 p-3 text-white shadow-lg hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2">
    <svg class="h-6 w-6" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 6.75h16.5M3.75 12h16.5m-16.5 5.25h16.5" />
    </svg>
  </button>
</div>

<!-- Sidebar -->
<aside class="hidden lg:flex lg:flex-shrink-0"
       data-controller="sidebar"
       data-sidebar-target="sidebar">
  <div class="flex w-64 flex-col border-r border-gray-200 bg-white">
    <div class="flex flex-1 flex-col overflow-y-auto pt-5 pb-4">
      <nav class="mt-5 flex-1 space-y-1 px-2">
        <%= link_to root_path,
            class: "group flex items-center px-2 py-2 text-sm font-medium rounded-md #{current_page?(root_path) ? 'bg-indigo-50 text-indigo-600' : 'text-gray-700 hover:bg-gray-50 hover:text-gray-900'}" do %>
          <svg class="mr-3 h-6 w-6 flex-shrink-0 #{current_page?(root_path) ? 'text-indigo-600' : 'text-gray-400 group-hover:text-gray-500'}"
               xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" d="M2.25 12l8.954-8.955c.44-.439 1.152-.439 1.591 0L21.75 12M4.5 9.75v10.125c0 .621.504 1.125 1.125 1.125H9.75v-4.875c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125V21h4.125c.621 0 1.125-.504 1.125-1.125V9.75M8.25 21h8.25" />
          </svg>
          Dashboard
        <% end %>

        <%= link_to "#",
            class: "group flex items-center px-2 py-2 text-sm font-medium rounded-md text-gray-700 hover:bg-gray-50 hover:text-gray-900" do %>
          <svg class="mr-3 h-6 w-6 flex-shrink-0 text-gray-400 group-hover:text-gray-500"
               xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" d="M9 12h3.75M9 15h3.75M9 18h3.75m3 .75H18a2.25 2.25 0 002.25-2.25V6.108c0-1.135-.845-2.098-1.976-2.192a48.424 48.424 0 00-1.123-.08m-5.801 0c-.065.21-.1.433-.1.664 0 .414.336.75.75.75h4.5a.75.75 0 00.75-.75 2.25 2.25 0 00-.1-.664m-5.8 0A2.251 2.251 0 0113.5 2.25H15c1.012 0 1.867.668 2.15 1.586m-5.8 0c-.376.023-.75.05-1.124.08C9.095 4.01 8.25 4.973 8.25 6.108V8.25m0 0H4.875c-.621 0-1.125.504-1.125 1.125v11.25c0 .621.504 1.125 1.125 1.125h9.75c.621 0 1.125-.504 1.125-1.125V9.375c0-.621-.504-1.125-1.125-1.125H8.25zM6.75 12h.008v.008H6.75V12zm0 3h.008v.008H6.75V15zm0 3h.008v.008H6.75V18z" />
          </svg>
          Tasks
          <span class="ml-auto inline-block py-0.5 px-3 text-xs font-medium rounded-full bg-gray-100 text-gray-600">12</span>
        <% end %>

        <%= link_to "#",
            class: "group flex items-center px-2 py-2 text-sm font-medium rounded-md text-gray-700 hover:bg-gray-50 hover:text-gray-900" do %>
          <svg class="mr-3 h-6 w-6 flex-shrink-0 text-gray-400 group-hover:text-gray-500"
               xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" d="M15 19.128a9.38 9.38 0 002.625.372 9.337 9.337 0 004.121-.952 4.125 4.125 0 00-7.533-2.493M15 19.128v-.003c0-1.113-.285-2.16-.786-3.07M15 19.128v.106A12.318 12.318 0 018.624 21c-2.331 0-4.512-.645-6.374-1.766l-.001-.109a6.375 6.375 0 0111.964-3.07M12 6.375a3.375 3.375 0 11-6.75 0 3.375 3.375 0 016.75 0zm8.25 2.25a2.625 2.625 0 11-5.25 0 2.625 2.625 0 015.25 0z" />
          </svg>
          Team
        <% end %>

        <%= link_to "#",
            class: "group flex items-center px-2 py-2 text-sm font-medium rounded-md text-gray-700 hover:bg-gray-50 hover:text-gray-900" do %>
          <svg class="mr-3 h-6 w-6 flex-shrink-0 text-gray-400 group-hover:text-gray-500"
               xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" d="M2.25 12.75V12A2.25 2.25 0 014.5 9.75h15A2.25 2.25 0 0121.75 12v.75m-8.69-6.44l-2.12-2.12a1.5 1.5 0 00-1.061-.44H4.5A2.25 2.25 0 002.25 6v12a2.25 2.25 0 002.25 2.25h15A2.25 2.25 0 0021.75 18V9a2.25 2.25 0 00-2.25-2.25h-5.379a1.5 1.5 0 01-1.06-.44z" />
          </svg>
          Files
        <% end %>

        <%= link_to "#",
            class: "group flex items-center px-2 py-2 text-sm font-medium rounded-md text-gray-700 hover:bg-gray-50 hover:text-gray-900" do %>
          <svg class="mr-3 h-6 w-6 flex-shrink-0 text-gray-400 group-hover:text-gray-500"
               xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" d="M3 13.125C3 12.504 3.504 12 4.125 12h2.25c.621 0 1.125.504 1.125 1.125v6.75C7.5 20.496 6.996 21 6.375 21h-2.25A1.125 1.125 0 013 19.875v-6.75zM9.75 8.625c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125v11.25c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V8.625zM16.5 4.125c0-.621.504-1.125 1.125-1.125h2.25C20.496 3 21 3.504 21 4.125v15.75c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V4.125z" />
          </svg>
          Analytics
        <% end %>

        <!-- Divider -->
        <div class="border-t border-gray-200 my-4"></div>

        <!-- Workspace Settings -->
        <% if current_workspace.present? %>
          <%= link_to edit_workspace_path(current_workspace),
              class: "group flex items-center px-2 py-2 text-sm font-medium rounded-md text-gray-700 hover:bg-gray-50 hover:text-gray-900" do %>
            <svg class="mr-3 h-6 w-6 flex-shrink-0 text-gray-400 group-hover:text-gray-500"
                 xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" d="M9.594 3.94c.09-.542.56-.94 1.11-.94h2.593c.55 0 1.02.398 1.11.94l.213 1.281c.063.374.313.686.645.87.074.04.147.083.22.127.324.196.72.257 1.075.124l1.217-.456a1.125 1.125 0 011.37.49l1.296 2.247a1.125 1.125 0 01-.26 1.431l-1.003.827c-.293.24-.438.613-.431.992a6.759 6.759 0 010 .255c-.007.378.138.75.43.99l1.005.828c.424.35.534.954.26 1.43l-1.298 2.247a1.125 1.125 0 01-1.369.491l-1.217-.456c-.355-.133-.75-.072-1.076.124a6.57 6.57 0 01-.22.128c-.331.183-.581.495-.644.869l-.213 1.28c-.09.543-.56.941-1.11.941h-2.594c-.55 0-1.02-.398-1.11-.94l-.213-1.281c-.062-.374-.312-.686-.644-.87a6.52 6.52 0 01-.22-.127c-.325-.196-.72-.257-1.076-.124l-1.217.456a1.125 1.125 0 01-1.369-.49l-1.297-2.247a1.125 1.125 0 01.26-1.431l1.004-.827c.292-.24.437-.613.43-.992a6.932 6.932 0 010-.255c.007-.378-.138-.75-.43-.99l-1.004-.828a1.125 1.125 0 01-.26-1.43l1.297-2.247a1.125 1.125 0 011.37-.491l1.216.456c.356.133.751.072 1.076-.124.072-.044.146-.087.22-.128.332-.183.582-.495.644-.869l.214-1.281z" />
              <path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
            </svg>
            Workspace Settings
          <% end %>
        <% end %>
      </nav>
    </div>

    <!-- Workspace Info Footer -->
    <% if current_workspace.present? %>
      <div class="flex flex-shrink-0 border-t border-gray-200 p-4">
        <div class="w-full">
          <div class="text-xs font-medium text-gray-500">Current Workspace</div>
          <div class="mt-1 text-sm font-medium text-gray-900 truncate"><%= current_workspace.name %></div>
          <div class="mt-1 text-xs text-gray-500">
            <%= pluralize(current_workspace.users.count, 'member') %>
          </div>
        </div>
      </div>
    <% end %>
  </div>
</aside>
```

### Step 4: Create Flash Messages Component (30 minutes)

Build auto-dismissing flash messages with Stimulus:

**File: `app/views/shared/_flash_messages.html.erb`**

```erb
<div class="fixed top-4 right-4 z-50 space-y-2" data-controller="flash">
  <% flash.each do |type, message| %>
    <div data-flash-target="message"
         data-action="click->flash#dismiss"
         class="pointer-events-auto w-full max-w-sm overflow-hidden rounded-lg bg-white shadow-lg ring-1 ring-black ring-opacity-5 transform transition-all duration-300 ease-in-out">
      <div class="p-4">
        <div class="flex items-start">
          <div class="flex-shrink-0">
            <% case type.to_sym %>
            <% when :notice, :success %>
              <svg class="h-6 w-6 text-green-400" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            <% when :alert, :error %>
              <svg class="h-6 w-6 text-red-400" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m9-.75a9 9 0 11-18 0 9 9 0 0118 0zm-9 3.75h.008v.008H12v-.008z" />
              </svg>
            <% when :warning %>
              <svg class="h-6 w-6 text-yellow-400" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z" />
              </svg>
            <% else %>
              <svg class="h-6 w-6 text-blue-400" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" d="M11.25 11.25l.041-.02a.75.75 0 011.063.852l-.708 2.836a.75.75 0 001.063.853l.041-.021M21 12a9 9 0 11-18 0 9 9 0 0118 0zm-9-3.75h.008v.008H12V8.25z" />
              </svg>
            <% end %>
          </div>
          <div class="ml-3 w-0 flex-1 pt-0.5">
            <p class="text-sm font-medium text-gray-900">
              <%= type.to_s.titleize %>
            </p>
            <p class="mt-1 text-sm text-gray-500">
              <%= message %>
            </p>
          </div>
          <div class="ml-4 flex flex-shrink-0">
            <button type="button"
                    class="inline-flex rounded-md bg-white text-gray-400 hover:text-gray-500 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2">
              <span class="sr-only">Close</span>
              <svg class="h-5 w-5" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                <path d="M6.28 5.22a.75.75 0 00-1.06 1.06L8.94 10l-3.72 3.72a.75.75 0 101.06 1.06L10 11.06l3.72 3.72a.75.75 0 101.06-1.06L11.06 10l3.72-3.72a.75.75 0 00-1.06-1.06L10 8.94 6.28 5.22z" />
              </svg>
            </button>
          </div>
        </div>
      </div>
      <!-- Progress bar -->
      <div class="h-1 bg-gray-100">
        <div data-flash-target="progress"
             class="h-full bg-indigo-600 transition-all duration-[5000ms] ease-linear"
             style="width: 100%"></div>
      </div>
    </div>
  <% end %>
</div>
```

### Step 5: Create Dropdown Stimulus Controller (30 minutes)

Handle dropdown menu interactions:

**File: `app/javascript/controllers/dropdown_controller.js`**

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]

  connect() {
    this.boundClose = this.close.bind(this)
  }

  toggle(event) {
    event.stopPropagation()

    if (this.menuTarget.classList.contains("hidden")) {
      this.open()
    } else {
      this.close()
    }
  }

  open() {
    // Close all other dropdowns first
    document.querySelectorAll('[data-dropdown-target="menu"]').forEach(menu => {
      if (menu !== this.menuTarget) {
        menu.classList.add("hidden")
      }
    })

    this.menuTarget.classList.remove("hidden")

    // Add click listener to close dropdown when clicking outside
    setTimeout(() => {
      document.addEventListener("click", this.boundClose)
    }, 10)
  }

  close() {
    this.menuTarget.classList.add("hidden")
    document.removeEventListener("click", this.boundClose)
  }

  disconnect() {
    document.removeEventListener("click", this.boundClose)
  }
}
```

### Step 6: Create Flash Messages Stimulus Controller (30 minutes)

Handle auto-dismissing flash messages:

**File: `app/javascript/controllers/flash_controller.js`**

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["message", "progress"]

  connect() {
    this.messageTargets.forEach((message, index) => {
      // Stagger the appearance of multiple messages
      setTimeout(() => {
        this.show(message)
        this.startAutoDismiss(message, index)
      }, index * 100)
    })
  }

  show(message) {
    // Animate in
    message.classList.add("translate-x-0", "opacity-100")
    message.classList.remove("translate-x-full", "opacity-0")
  }

  startAutoDismiss(message, index) {
    const progressBar = this.progressTargets[index]

    // Start progress bar animation
    setTimeout(() => {
      progressBar.style.width = "0%"
    }, 100)

    // Auto-dismiss after 5 seconds
    setTimeout(() => {
      this.dismissMessage(message)
    }, 5000)
  }

  dismiss(event) {
    const message = event.currentTarget.closest('[data-flash-target="message"]')
    this.dismissMessage(message)
  }

  dismissMessage(message) {
    // Animate out
    message.classList.add("translate-x-full", "opacity-0")
    message.classList.remove("translate-x-0", "opacity-100")

    // Remove from DOM after animation
    setTimeout(() => {
      message.remove()
    }, 300)
  }
}
```

### Step 7: Create Sidebar Stimulus Controller (Mobile) (20 minutes)

Handle mobile sidebar toggle:

**File: `app/javascript/controllers/sidebar_controller.js`**

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sidebar"]

  toggle() {
    const sidebar = this.sidebarTarget

    if (sidebar.classList.contains("hidden")) {
      this.open()
    } else {
      this.close()
    }
  }

  open() {
    this.sidebarTarget.classList.remove("hidden")
    this.sidebarTarget.classList.add("fixed", "inset-0", "z-40", "lg:static", "lg:z-auto")

    // Add backdrop
    this.createBackdrop()
  }

  close() {
    this.sidebarTarget.classList.add("hidden")
    this.removeBackdrop()
  }

  createBackdrop() {
    const backdrop = document.createElement("div")
    backdrop.className = "fixed inset-0 bg-gray-600 bg-opacity-75 z-30 lg:hidden"
    backdrop.dataset.action = "click->sidebar#close"
    backdrop.id = "sidebar-backdrop"
    document.body.appendChild(backdrop)
  }

  removeBackdrop() {
    const backdrop = document.getElementById("sidebar-backdrop")
    if (backdrop) {
      backdrop.remove()
    }
  }
}
```

### Step 8: Add Helper Methods (15 minutes)

Create helper methods for layout:

**File: `app/helpers/application_helper.rb`**

```ruby
module ApplicationHelper
  def current_workspace
    @current_workspace ||= begin
      if session[:workspace_id]
        current_user.workspaces.find_by(id: session[:workspace_id])
      else
        current_user.workspaces.first
      end
    end
  end

  def flash_class(type)
    case type.to_sym
    when :notice, :success
      "bg-green-50 text-green-800 border-green-200"
    when :alert, :error
      "bg-red-50 text-red-800 border-red-200"
    when :warning
      "bg-yellow-50 text-yellow-800 border-yellow-200"
    else
      "bg-blue-50 text-blue-800 border-blue-200"
    end
  end

  def active_link_class(path)
    current_page?(path) ? "bg-indigo-50 text-indigo-600" : "text-gray-700 hover:bg-gray-50"
  end
end
```

### Step 9: Update Routes (10 minutes)

Add workspace switching route:

**File: `config/routes.rb`**

```ruby
Rails.application.routes.draw do
  devise_for :users

  root "dashboard#index"

  resources :workspaces do
    member do
      post :switch
    end
  end

  # Add other routes here
end
```

**File: `app/controllers/workspaces_controller.rb`** (add switch action)

```ruby
class WorkspacesController < ApplicationController
  before_action :authenticate_user!

  def switch
    workspace = current_user.workspaces.find(params[:id])
    session[:workspace_id] = workspace.id
    redirect_to root_path, notice: "Switched to #{workspace.name}"
  end

  # ... other actions
end
```

## Workflow Diagram

```
User Interaction Flow:
┌─────────────────────────────────────────────────────────────┐
│                    User Visits Application                   │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
              ┌──────────────────────┐
              │  Authenticated?      │
              └──────┬───────────────┘
                     │
         ┌───────────┴───────────┐
         │                       │
         ▼ No                    ▼ Yes
┌────────────────┐      ┌────────────────────┐
│ Public Layout  │      │ Application Layout │
│ (Auth Pages)   │      │ with Nav & Sidebar │
└────────────────┘      └────────┬───────────┘
                                 │
                    ┌────────────┴────────────┐
                    │                         │
                    ▼                         ▼
         ┌──────────────────┐      ┌──────────────────┐
         │ Navbar Actions:  │      │ Sidebar Actions: │
         │ - Switch WS      │      │ - Navigate       │
         │ - User Menu      │      │ - View Settings  │
         │ - Notifications  │      │ - See WS Info    │
         └──────────────────┘      └──────────────────┘
                    │                         │
                    └────────────┬────────────┘
                                 │
                                 ▼
                    ┌────────────────────────┐
                    │   Main Content Area    │
                    │   - Flash Messages     │
                    │   - Page Content       │
                    └────────────────────────┘
```

## Success Criteria

### Visual & UX Requirements
- [ ] Navbar displays correctly with logo, workspace switcher, and user menu
- [ ] Workspace switcher shows all user's workspaces with current one highlighted
- [ ] User dropdown shows profile, settings, and sign out options
- [ ] Sidebar displays navigation links with icons and active state
- [ ] Sidebar shows workspace info in footer
- [ ] Flash messages appear with correct styling based on type
- [ ] Flash messages auto-dismiss after 5 seconds
- [ ] Flash messages can be manually dismissed
- [ ] Progress bar animates on flash messages

### Responsive Design
- [ ] Layout works on mobile (< 768px)
- [ ] Layout works on tablet (768px - 1024px)
- [ ] Layout works on desktop (> 1024px)
- [ ] Sidebar hidden on mobile with toggle button
- [ ] Navbar adapts to mobile (hide user email, etc.)
- [ ] Dropdowns work on all screen sizes

### Functionality
- [ ] Clicking workspace switcher opens dropdown
- [ ] Selecting workspace switches context
- [ ] User menu dropdown opens/closes correctly
- [ ] Sign out button works
- [ ] Sidebar navigation links work
- [ ] Active page highlighted in sidebar
- [ ] Flash messages display for all flash types (notice, alert, error, warning)
- [ ] Multiple flash messages stack correctly

### Code Quality
- [ ] All Stimulus controllers properly connected
- [ ] No console errors
- [ ] Tailwind classes applied correctly
- [ ] ERB partials properly organized
- [ ] Helper methods work as expected
- [ ] Accessible (keyboard navigation, ARIA labels)

## Testing Examples

### Manual Testing Checklist

**1. Navbar Testing:**
```
✓ Click logo - redirects to root
✓ Click workspace switcher - dropdown opens
✓ Select different workspace - switches workspace
✓ Click "Create New Workspace" - navigates to new workspace form
✓ Click user avatar - dropdown opens
✓ Click "Your Profile" - navigates to profile edit
✓ Click "Sign Out" - signs out user
```

**2. Sidebar Testing:**
```
✓ Click each navigation link - navigates correctly
✓ Active page shows highlighted state
✓ Workspace info displays correctly
✓ Member count shows correct number
✓ On mobile - sidebar hidden by default
✓ On mobile - toggle button shows/hides sidebar
```

**3. Flash Messages Testing:**
```
✓ Success message shows green icon and styling
✓ Error message shows red icon and styling
✓ Warning message shows yellow icon and styling
✓ Info message shows blue icon and styling
✓ Message auto-dismisses after 5 seconds
✓ Progress bar animates from 100% to 0%
✓ Click X button - message dismisses immediately
✓ Multiple messages stack vertically
```

### System Tests

**File: `test/system/layout_test.rb`**

```ruby
require "application_system_test_case"

class LayoutTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @workspace = workspaces(:one)
    sign_in @user
  end

  test "navbar displays correctly" do
    visit root_path

    assert_selector "nav", text: "AEO"
    assert_selector "button", text: @workspace.name
    assert_selector "button", text: @user.email
  end

  test "workspace switcher works" do
    workspace2 = workspaces(:two)
    visit root_path

    click_button @workspace.name
    click_link workspace2.name

    assert_text "Switched to #{workspace2.name}"
    assert_selector "button", text: workspace2.name
  end

  test "user menu works" do
    visit root_path

    click_button @user.email
    assert_selector "a", text: "Your Profile"
    assert_selector "a", text: "Settings"
    assert_button "Sign Out"
  end

  test "sidebar navigation works" do
    visit root_path

    assert_selector "aside nav"
    assert_link "Dashboard"
    assert_link "Tasks"
    assert_link "Team"
    assert_link "Files"
  end

  test "flash messages display and auto-dismiss" do
    visit root_path

    # Trigger a flash message (you'll need to implement this)
    click_button "Test Flash"

    assert_selector "[data-flash-target='message']"

    # Wait for auto-dismiss
    sleep 6
    assert_no_selector "[data-flash-target='message']"
  end

  test "mobile sidebar toggle works", driver: :mobile do
    visit root_path

    # Sidebar should be hidden on mobile
    assert_selector "aside.hidden"

    # Click toggle button
    find("button[data-action='click->sidebar#toggle']").click

    # Sidebar should be visible
    assert_no_selector "aside.hidden"
  end
end
```

### Controller Tests

**File: `test/controllers/workspaces_controller_test.rb`**

```ruby
require "test_helper"

class WorkspacesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @workspace = workspaces(:one)
    sign_in @user
  end

  test "should switch workspace" do
    workspace2 = workspaces(:two)

    post switch_workspace_path(workspace2)

    assert_redirected_to root_path
    assert_equal workspace2.id, session[:workspace_id]
    assert_equal "Switched to #{workspace2.name}", flash[:notice]
  end

  test "should not switch to workspace user doesn't belong to" do
    other_workspace = workspaces(:other_user_workspace)

    assert_raises(ActiveRecord::RecordNotFound) do
      post switch_workspace_path(other_workspace)
    end
  end
end
```

## Troubleshooting

### Common Issues and Solutions

#### 1. Dropdowns Not Working

**Problem:** Clicking dropdown buttons doesn't open menus

**Solutions:**
```bash
# Check Stimulus controller is registered
bin/rails stimulus:manifest:update

# Verify controller is connected
# Open browser console and check for errors
# Look for: "dropdown controller connected"

# Check data attributes match
# Button should have: data-action="click->dropdown#toggle"
# Menu should have: data-dropdown-target="menu"
```

#### 2. Flash Messages Not Auto-Dismissing

**Problem:** Flash messages stay visible forever

**Solutions:**
```javascript
// Check flash controller is connected
// Verify progress bar target exists
// Check console for JavaScript errors

// Debug in flash_controller.js:
connect() {
  console.log("Flash controller connected")
  console.log("Message targets:", this.messageTargets.length)
  console.log("Progress targets:", this.progressTargets.length)
  // ... rest of code
}
```

#### 3. Sidebar Not Showing on Desktop

**Problem:** Sidebar is hidden even on large screens

**Solutions:**
```erb
<!-- Check sidebar classes -->
<!-- Should have: class="hidden lg:flex lg:flex-shrink-0" -->

<!-- Verify Tailwind is processing lg: breakpoint -->
<!-- Check tailwind.config.js includes proper content paths -->

<!-- Test with browser dev tools -->
<!-- Resize window and check if lg:flex applies at 1024px+ -->
```

#### 4. Current Workspace Not Displaying

**Problem:** `current_workspace` returns nil

**Solutions:**
```ruby
# Check helper method in ApplicationHelper
# Verify user has workspaces
User.find(1).workspaces.count # Should be > 0

# Check session
session[:workspace_id] # Should have a value

# Debug in controller
def index
  puts "Current workspace: #{current_workspace.inspect}"
  puts "Session workspace_id: #{session[:workspace_id]}"
  puts "User workspaces: #{current_user.workspaces.pluck(:id)}"
end
```

#### 5. Tailwind Styles Not Applying

**Problem:** Layout looks unstyled

**Solutions:**
```bash
# Rebuild Tailwind CSS
bin/rails tailwindcss:build

# Check if Tailwind is watching in development
bin/rails tailwindcss:watch

# Verify content paths in tailwind.config.js
module.exports = {
  content: [
    './app/views/**/*.html.erb',
    './app/helpers/**/*.rb',
    './app/javascript/**/*.js'
  ]
}

# Clear browser cache and hard reload
```

#### 6. Mobile Sidebar Not Toggling

**Problem:** Mobile sidebar button doesn't work

**Solutions:**
```javascript
// Check sidebar controller is connected
// Verify button has correct data-action
// data-action="click->sidebar#toggle"

// Check z-index conflicts
// Sidebar should have z-40, backdrop z-30

// Debug in sidebar_controller.js:
toggle() {
  console.log("Toggle called")
  console.log("Sidebar target:", this.sidebarTarget)
  // ... rest of code
}
```

#### 7. Active Link Not Highlighting

**Problem:** Current page not highlighted in sidebar

**Solutions:**
```ruby
# Check current_page? helper is working
<%= link_to root_path,
    class: "... #{current_page?(root_path) ? 'bg-indigo-50 text-indigo-600' : 'text-gray-700'}" %>

# For nested routes, use a more flexible check:
<%= link_to tasks_path,
    class: "... #{request.path.start_with?('/tasks') ? 'bg-indigo-50 text-indigo-600' : 'text-gray-700'}" %>

# Or create a helper method:
def active_nav_class(path)
  current_page?(path) || request.path.start_with?(path) ?
    'bg-indigo-50 text-indigo-600' : 'text-gray-700'
end
```

#### 8. Workspace Switcher Shows Wrong Workspaces

**Problem:** User sees workspaces they don't belong to

**Solutions:**
```ruby
# Verify workspace association
# In User model:
has_many :workspace_memberships
has_many :workspaces, through: :workspace_memberships

# In navbar partial:
<% current_user.workspaces.each do |workspace| %>
  <!-- Only shows user's workspaces -->
<% end %>

# Check workspace membership
WorkspaceMembership.where(user: current_user).pluck(:workspace_id)
```

## Performance Optimization

### 1. Reduce Database Queries

```ruby
# In ApplicationController
def current_workspace
  @current_workspace ||= begin
    if session[:workspace_id]
      # Use includes to eager load associations
      current_user.workspaces
        .includes(:users)
        .find_by(id: session[:workspace_id])
    else
      current_user.workspaces.includes(:users).first
    end
  end
end
```

### 2. Cache Workspace List

```erb
<!-- In navbar partial -->
<% cache ["workspace-switcher", current_user, current_user.workspaces.maximum(:updated_at)] do %>
  <% current_user.workspaces.each do |workspace| %>
    <!-- workspace links -->
  <% end %>
<% end %>
```

### 3. Optimize Tailwind Build

```javascript
// tailwind.config.js
module.exports = {
  content: [
    './app/views/**/*.html.erb',
    './app/helpers/**/*.rb',
    './app/javascript/**/*.js'
  ],
  theme: {
    extend: {},
  },
  plugins: [
    require('@tailwindcss/forms'),
  ],
  // Add safelist for dynamic classes if needed
  safelist: [
    'bg-indigo-50',
    'text-indigo-600',
  ]
}
```

## Accessibility Improvements

### 1. Keyboard Navigation

```erb
<!-- Add keyboard support to dropdowns -->
<button type="button"
        data-action="click->dropdown#toggle keydown.esc->dropdown#close"
        aria-expanded="false"
        aria-haspopup="true">
  Workspace Switcher
</button>

<!-- Add focus management -->
<div data-dropdown-target="menu"
     role="menu"
     aria-orientation="vertical"
     tabindex="-1">
  <!-- menu items -->
</div>
```

### 2. Screen Reader Support

```erb
<!-- Add ARIA labels -->
<nav aria-label="Main navigation">
  <!-- navigation links -->
</nav>

<aside aria-label="Sidebar">
  <!-- sidebar content -->
</aside>

<!-- Add live region for flash messages -->
<div role="alert" aria-live="polite" aria-atomic="true">
  <%= render "shared/flash_messages" %>
</div>
```

### 3. Focus Indicators

```css
/* Add to application.tailwind.css */
@layer components {
  .focus-visible:focus {
    @apply outline-none ring-2 ring-indigo-500 ring-offset-2;
  }
}
```

## Next Steps

After completing this task:

1. **Test thoroughly** - Go through all manual testing checklists
2. **Run system tests** - Ensure all automated tests pass
3. **Check responsive design** - Test on actual mobile devices
4. **Verify accessibility** - Use screen reader and keyboard only
5. **Get feedback** - Have team members review the UI/UX
6. **Document** - Update any team documentation about navigation
7. **Move to Task 07** - Dashboard & Workspace Management

## Additional Resources

- [Tailwind CSS Documentation](https://tailwindcss.com/docs)
- [Stimulus Handbook](https://stimulus.hotwired.dev/handbook/introduction)
- [Heroicons](https://heroicons.com/) - Icon library used
- [Tailwind UI Components](https://tailwindui.com/components) - More examples
- [Rails Layouts Guide](https://guides.rubyonrails.org/layouts_and_rendering.html)

## Estimated Time Breakdown

- Step 1: Application Layout (30 min)
- Step 2: Navbar (1 hour)
- Step 3: Sidebar (45 min)
- Step 4: Flash Messages (30 min)
- Step 5: Dropdown Controller (30 min)
- Step 6: Flash Controller (30 min)
- Step 7: Sidebar Controller (20 min)
- Step 8: Helper Methods (15 min)
- Step 9: Routes & Controller (10 min)
- Testing & Debugging (1 hour)
- Responsive Design Tweaks (30 min)
- Accessibility Improvements (20 min)

**Total: ~6 hours**

---

**Status:** Ready for Implementation
**Priority:** High
**Complexity:** Medium
**Dependencies:** Task 05 (Authentication) must be complete
