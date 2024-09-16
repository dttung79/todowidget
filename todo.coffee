# index.coffee

command: ""

refreshFrequency: 60000 # Refresh every minute

render: -> """
  <div class="widget">
    <div class="widget-header">
      <span class="widget-icon">📋</span>
      <span class="widget-title">Do them now!</span>
      <span class="widget-controls">
        <button class="add-task">➕</button>
        <button class="settings">⚙️</button>
      </span>
    </div>
    <div class="task-list"></div>
    <div class="add-task-form" style="display: none;">
      <input type="text" id="task-name" placeholder="Task name">
      <input type="color" id="task-color" value="#ffffff">
      <input type="datetime-local" id="task-deadline">
      <button id="save-task">Save</button>
      <button id="cancel-add-task">Cancel</button>
    </div>
    <div class="edit-task-form" style="display: none;">
      <input type="text" id="edit-task-name" placeholder="Task name">
      <input type="color" id="edit-task-color" value="#ffffff">
      <input type="datetime-local" id="edit-task-deadline">
      <button id="save-edit-task">Save</button>
      <button id="cancel-edit-task">Cancel</button>
    </div>
    <div class="settings-form" style="display: none;">
      <input type="range" id="opacity" min="0" max="100" value="50">
      <input type="time" id="reminder-time" value="01:00">
      <input type="color" id="text-color" value="#000000">
      <input type="color" id="widget-bg-color" value="#ffffff">
      <input type="text" id="widget-title" value="Do them now!">
      <button id="save-settings">Save</button>
      <button id="cancel-settings">Cancel</button>
    </div>
  </div>
"""

style: """
  top: 10px
  left: 10px
  
  .widget {
    font-family: Arial, sans-serif;
    background-color: rgba(255, 255, 255, 0.5);
    border-radius: 10px;
    padding: 10px;
    width: 300px;
  }

  .widget-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 10px;
  }

  .widget-icon {
    font-size: 24px;
  }

  .widget-title {
    font-size: 18px;
    font-weight: bold;
  }

  .widget-controls button {
    background: none;
    border: none;
    font-size: 18px;
    cursor: pointer;
  }

  .task-list {
    max-height: 300px;
    overflow-y: auto;
  }

  .task {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 5px;
    margin-bottom: 5px;
    border-radius: 5px;
  }

  .task-name {
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    max-width: 200px;
    display: inline-block;
    cursor: pointer;
  }

  .task-controls {
    display: flex;
    align-items: center;
  }

  .task-controls button {
    background: none;
    border: none;
    font-size: 14px;
    cursor: pointer;
    margin-left: 5px;
  }

  .deadline-button {
    width: 20px;
    height: 20px;
    border-radius: 50%;
    display: inline-block;
    text-align: center;
    line-height: 20px;
  }

  .add-task-form, .edit-task-form, .settings-form {
    margin-top: 10px;
  }

  .add-task-form input, .edit-task-form input, .settings-form input {
    display: block;
    margin-bottom: 5px;
    width: 100%;
  }

  .add-task-form button, .edit-task-form button, .settings-form button {
    margin-top: 5px;
  }

  .tooltip {
    position: absolute;
    background-color: rgba(0, 0, 0, 0.8);
    color: white;
    padding: 5px 10px;
    border-radius: 5px;
    font-size: 14px;
    z-index: 1000;
    max-width: 300px;
    word-wrap: break-word;
    pointer-events: none;
  }
"""

update: (output, domEl) -> 
  # This function will be called every time the widget refreshes
  # You can put any dynamic update logic here

afterRender: (domEl) ->
  tasks = []
  settings = {
    opacity: 50,
    reminderTime: '01:00',
    textColor: '#000000',
    widgetBgColor: '#ffffff',
    widgetTitle: 'Do them now!'
  }
  tooltipTimer = null
  currentTooltip = null

  loadTasks = ->
    savedTasks = localStorage.getItem('tasks')
    if savedTasks
      tasks = JSON.parse(savedTasks)
      renderTasks()

  saveTasks = ->
    localStorage.setItem('tasks', JSON.stringify(tasks))

  loadSettings = ->
    savedSettings = localStorage.getItem('settings')
    if savedSettings
      settings = JSON.parse(savedSettings)
      applySettings()

  saveSettings = ->
    localStorage.setItem('settings', JSON.stringify(settings))

  truncateText = (text, maxLength) ->
    if text.length > maxLength
      return text.substring(0, maxLength) + '...'
    return text

  renderTasks = ->
    taskList = domEl.querySelector('.task-list')
    taskList.innerHTML = ''
    
    tasks.sort((a, b) ->
      if !a.deadline then return 1
      if !b.deadline then return -1
      return new Date(a.deadline) - new Date(b.deadline)
    )

    tasks.forEach((task, index) ->
      taskElement = document.createElement('div')
      taskElement.className = 'task'
      taskElement.style.backgroundColor = task.color || 'transparent'

      taskName = document.createElement('span')
      taskName.className = 'task-name'
      truncatedName = truncateText(task.name, 100)
      taskName.textContent = truncatedName
      if truncatedName != task.name
        taskName.setAttribute('data-full-text', task.name)
        taskName.addEventListener('mouseover', (e) -> showTooltip(e, task.name))
        taskName.addEventListener('mouseout', hideTooltip)
      taskName.addEventListener('click', -> showTaskDetails(index))
      taskElement.appendChild(taskName)

      controls = document.createElement('div')
      controls.className = 'task-controls'

      completeButton = document.createElement('button')
      completeButton.textContent = '✓'
      completeButton.onclick = -> completeTask(index)
      controls.appendChild(completeButton)

      editButton = document.createElement('button')
      editButton.textContent = '✏️'
      editButton.onclick = -> editTask(index)
      controls.appendChild(editButton)

      if task.deadline
        deadlineButton = document.createElement('button')
        deadlineButton.className = 'deadline-button'
        deadlineButton.textContent = '⏰'
        progress = getDeadlineProgress(task.deadline, task.createdAt)
        deadlineButton.style.background = "conic-gradient(#{getProgressColor(progress)} #{progress}%, transparent #{progress}%)"
        controls.appendChild(deadlineButton)

      taskElement.appendChild(controls)
      taskList.appendChild(taskElement)
    )

  showTooltip = (event, fullText) ->
    clearTimeout(tooltipTimer)
    hideTooltip()
    tooltipTimer = setTimeout( ->
      tooltip = document.createElement('div')
      tooltip.className = 'tooltip'
      tooltip.textContent = fullText
      tooltip.style.left = event.pageX + 'px'
      tooltip.style.top = (event.pageY + 20) + 'px'
      domEl.appendChild(tooltip)
      currentTooltip = tooltip
    , 500) # 500ms delay before showing tooltip

  hideTooltip = ->
    clearTimeout(tooltipTimer)
    if currentTooltip
      currentTooltip.remove()
      currentTooltip = null

  showTaskDetails = (index) ->
    task = tasks[index]
    domEl.querySelector('#edit-task-name').value = task.name
    domEl.querySelector('#edit-task-deadline').value = task.deadline || ''
    domEl.querySelector('.edit-task-form').style.display = 'block'
    domEl.querySelector('#save-edit-task').style.display = 'none'
    domEl.querySelector('#edit-task-color').style.display = 'none'
    domEl.querySelector('#cancel-edit-task').textContent = 'Close'
    domEl.querySelector('#cancel-edit-task').onclick = ->
      domEl.querySelector('.edit-task-form').style.display = 'none'
      domEl.querySelector('#save-edit-task').style.display = 'inline-block'
      domEl.querySelector('#edit-task-color').style.display = 'block'
      domEl.querySelector('#cancel-edit-task').textContent = 'Cancel'
      domEl.querySelector('#cancel-edit-task').onclick = -> domEl.querySelector('.edit-task-form').style.display = 'none'

  addTask = ->
    name = domEl.querySelector('#task-name').value
    color = domEl.querySelector('#task-color').value
    deadline = domEl.querySelector('#task-deadline').value

    if name
      tasks.push({ name, color, deadline, createdAt: new Date().toISOString() })
      saveTasks()
      renderTasks()
      domEl.querySelector('.add-task-form').style.display = 'none'

  editTask = (index) ->
    task = tasks[index]
    domEl.querySelector('#edit-task-name').value = task.name
    domEl.querySelector('#edit-task-color').value = task.color || '#ffffff'
    domEl.querySelector('#edit-task-color').style.display = 'block'
    domEl.querySelector('#edit-task-deadline').value = task.deadline || ''
    domEl.querySelector('.edit-task-form').style.display = 'block'
    domEl.querySelector('#save-edit-task').style.display = 'inline-block'
    domEl.querySelector('#save-edit-task').onclick = ->
      task.name = domEl.querySelector('#edit-task-name').value
      task.color = domEl.querySelector('#edit-task-color').value
      task.deadline = domEl.querySelector('#edit-task-deadline').value
      saveTasks()
      renderTasks()
      domEl.querySelector('.edit-task-form').style.display = 'none'

  completeTask = (index) ->
    tasks.splice(index, 1)
    saveTasks()
    renderTasks()

  getDeadlineProgress = (deadline, createdAt) ->
    now = new Date()
    deadlineDate = new Date(deadline)
    createdDate = new Date(createdAt)
    totalTime = deadlineDate - createdDate
    elapsedTime = now - createdDate
    return Math.min(100, Math.max(0, (elapsedTime / totalTime) * 100))

  getProgressColor = (progress) ->
    hue = (1 - progress / 100) * 120 # 120 is green, 0 is red
    return "hsl(#{hue}, 100%, 50%)"

  applySettings = ->
    widget = domEl.querySelector('.widget')
    widget.style.opacity = settings.opacity / 100
    widget.style.backgroundColor = settings.widgetBgColor
    widget.style.color = settings.textColor
    domEl.querySelector('.widget-title').textContent = settings.widgetTitle

  showAddTaskForm = ->
    domEl.querySelector('.add-task-form').style.display = 'block'

  showSettingsForm = ->
    domEl.querySelector('.settings-form').style.display = 'block'

  saveSettingsForm = ->
    settings.opacity = domEl.querySelector('#opacity').value
    settings.reminderTime = domEl.querySelector('#reminder-time').value
    settings.textColor = domEl.querySelector('#text-color').value
    settings.widgetBgColor = domEl.querySelector('#widget-bg-color').value
    settings.widgetTitle = domEl.querySelector('#widget-title').value

    saveSettings()
    applySettings()
    domEl.querySelector('.settings-form').style.display = 'none'

  hideWidget = ->
    domEl.querySelector('.widget').style.display = 'none'

  showWidget = ->
    domEl.querySelector('.widget').style.display = 'block'

  # Event listeners
  domEl.querySelector('.add-task').addEventListener('click', showAddTaskForm)
  domEl.querySelector('.settings').addEventListener('click', showSettingsForm)
  domEl.querySelector('#save-task').addEventListener('click', addTask)
  domEl.querySelector('#save-settings').addEventListener('click', saveSettingsForm)
  domEl.querySelector('#cancel-add-task').addEventListener('click', -> domEl.querySelector('.add-task-form').style.display = 'none')
  domEl.querySelector('#cancel-settings').addEventListener('click', -> domEl.querySelector('.settings-form').style.display = 'none')
  domEl.querySelector('#cancel-edit-task').addEventListener('click', -> domEl.querySelector('.edit-task-form').style.display = 'none')

  # Initialize
  loadTasks()
  loadSettings()

  # Set up reminder
  setInterval(->
    now = new Date()
    [hours, minutes] = settings.reminderTime.split(':')
    if now.getHours() == parseInt(hours) && now.getMinutes() == parseInt(minutes)
      showWidget()
  , 60000) # Check every minute

  # Hide widget button
  hideButton = document.createElement('button')
  hideButton.textContent = '−'
  hideButton.onclick = hideWidget
  domEl.querySelector('.widget-controls').appendChild(hideButton)