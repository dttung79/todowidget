# index.coffee

command: ""

refreshFrequency: 360000 # Refresh every hour

render: -> """
  <div class="widget">
    <div class="widget-header">
      <span class="widget-icon">📋</span>
      <span class="widget-title">Do them now!</span>
      <span class="widget-controls">
        <button class="add-task">➕</button>
        <button class="calendar-toggle">📅</button>
        <button class="settings">⚙️</button>
      </span>
    </div>
    <div class="task-list"></div>
    <div class="calendar-container" style="display: none;"></div>
    <div class="add-task-form" style="display: none;">
      <label for="task-name">Task Name:</label>
      <input type="text" id="task-name" placeholder="Enter task name">
      <label for="task-color">Task Color:</label>
      <input type="color" id="task-color" value="#ffff">
      <label for="task-deadline">Deadline:</label>
      <input type="datetime-local" id="task-deadline">
      <button id="save-task">Save</button>
      <button id="cancel-add-task">Cancel</button>
    </div>
    <div class="edit-task-form" style="display: none;">
      <input type="text" id="edit-task-name" placeholder="Task name">
      <input type="color" id="edit-task-color" value="#ffff">
      <input type="datetime-local" id="edit-task-deadline">
      <button id="save-edit-task">Save</button>
      <button id="cancel-edit-task">Cancel</button>
    </div>
    <div class="confirm-complete-task-form" style="display: none;">
      <p>Are you sure you want to complete this task?</p>
      <button id="confirm-complete-yes">Yes</button>
      <button id="confirm-complete-no">No</button>
    </div>
    <div class="settings-form" style="display: none;">
      <label for="opacity">Opacity:</label>
      <input type="range" id="opacity" min="0" max="100" value="50">
      <label for="reminder-time">Reminder Time:</label>
      <input type="time" id="reminder-time" value="01:00">
      <label for="text-color">Text Color:</label>
      <input type="color" id="text-color" value="#0000">
      <label for="widget-bg-color">Background Color:</label>
      <input type="color" id="widget-bg-color" value="#ffff">
      <label for="widget-title">Widget Title:</label>
      <input type="text" id="widget-title" value="Do them now!">
      <button id="save-settings">Save</button>
      <button id="cancel-settings">Cancel</button>
    </div>
  </div>
"""

style: """
  @import url("style.css")
"""

update: (output, domEl) -> 
  # This function will be called every time the widget refreshes
  # You can put any dynamic update logic here

afterRender: (domEl) ->
  tasks = []
  settings = {
    opacity: 50,
    reminderTime: '01:00',
    textColor: '#0000',
    widgetBgColor: '#ffff',
    widgetTitle: 'Do them now!'
  }
  tooltipTimer = null
  currentTooltip = null
  currentCompleteTaskIndex = null
  calendarVisible = false
  currentCalendarDate = new Date()

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
      truncatedName = truncateText(task.name, 300)
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
      completeButton.onclick = ->
        showConfirmCompleteTaskForm(index)
      controls.appendChild(completeButton)

      editButton = document.createElement('button')
      editButton.textContent = '✏️'
      editButton.onclick = -> editTask(index)
      controls.appendChild(editButton)

      deadlineIndicator = document.createElement('div')
      deadlineIndicator.className = 'deadline-indicator'
      
      if task.deadline
        progress = getDeadlineProgress(task.deadline, task.createdAt)
        color = getProgressColor(progress)
        deadlineIndicator.style.background = "conic-gradient(
          #{color} 0deg #{progress * 3.6}deg,
          transparent #{progress * 3.6}deg 360deg
        )"
      else
        deadlineIndicator.style.background = "linear-gradient(to top right, transparent calc(50% - 1px), black, transparent calc(50% + 1px))"
      
      controls.appendChild(deadlineIndicator)

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
    editForm = domEl.querySelector('.edit-task-form')
    # check if the form is already open then close it
    if editForm.style.display == 'block'
      editForm.style.display = 'none'
      return
    editForm.innerHTML = ''
    
    taskNameLabel = document.createElement('label')
    taskNameLabel.textContent = 'Task Name:'
    editForm.appendChild(taskNameLabel)
    
    taskNameInput = document.createElement('input')
    taskNameInput.type = 'text'
    taskNameInput.value = task.name
    editForm.appendChild(taskNameInput)
    
    deadlineLabel = document.createElement('label')
    deadlineLabel.textContent = 'Deadline:'
    editForm.appendChild(deadlineLabel)
    
    deadlineInput = document.createElement('input')
    deadlineInput.type = 'datetime-local'
    deadlineInput.value = task.deadline
    editForm.appendChild(deadlineInput)
    
    closeButton = document.createElement('button')
    closeButton.textContent = 'Close'
    closeButton.onclick = -> editForm.style.display = 'none'
    editForm.appendChild(closeButton)
    
    editForm.style.display = 'block'
    editForm.setAttribute('data-task-index', index)

  addTask = ->
    name = domEl.querySelector('#task-name').value
    color = domEl.querySelector('#task-color').value
    deadline = domEl.querySelector('#task-deadline').value

    if name
      tasks.push({ name, color, deadline, createdAt: new Date().toISOString() })
      saveTasks()
      renderTasks()
      renderCalendar() # Update calendar when tasks change
      domEl.querySelector('.add-task-form').style.display = 'none'

  editTask = (index) ->
    task = tasks[index]
    editForm = domEl.querySelector('.edit-task-form')
    editForm.innerHTML = ''
    
    taskNameLabel = document.createElement('label')
    taskNameLabel.textContent = 'Task Name:'
    editForm.appendChild(taskNameLabel)
    
    taskNameInput = document.createElement('input')
    taskNameInput.type = 'text'
    taskNameInput.value = task.name
    editForm.appendChild(taskNameInput)
    
    deadlineLabel = document.createElement('label')
    deadlineLabel.textContent = 'Deadline:'
    editForm.appendChild(deadlineLabel)
    
    deadlineInput = document.createElement('input')
    deadlineInput.type = 'datetime-local'
    deadlineInput.value = task.deadline
    editForm.appendChild(deadlineInput)
    
    saveButton = document.createElement('button')
    saveButton.textContent = 'Save'
    saveButton.onclick = ->
      task.name = taskNameInput.value
      task.deadline = deadlineInput.value
      saveTasks()
      renderTasks()
      editForm.style.display = 'none'
    editForm.appendChild(saveButton)
    # add cancel button
    cancelButton = document.createElement('button')
    cancelButton.textContent = 'Cancel'
    cancelButton.onclick = -> editForm.style.display = 'none'
    editForm.appendChild(cancelButton)
    
    editForm.style.display = 'block'
    editForm.setAttribute('data-task-index', index)

  completeTask = (index) ->
    tasks.splice(index, 1)
    saveTasks()
    renderTasks()
    renderCalendar() # Update calendar when tasks change

  # Confirmation dialog functions
  showConfirmCompleteTaskForm = (index) ->
    currentCompleteTaskIndex = index
    domEl.querySelector('.confirm-complete-task-form').style.display = 'block'

  hideConfirmCompleteTaskForm = ->
    domEl.querySelector('.confirm-complete-task-form').style.display = 'none'
    currentCompleteTaskIndex = null

  completeTaskConfirmed = ->
    if currentCompleteTaskIndex != null
      completeTask(currentCompleteTaskIndex)
      hideConfirmCompleteTaskForm()

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
    domEl.querySelector('#opacity').value = settings.opacity
    domEl.querySelector('#reminder-time').value = settings.reminderTime
    domEl.querySelector('#text-color').value = settings.textColor
    domEl.querySelector('#widget-bg-color').value = settings.widgetBgColor
    domEl.querySelector('#widget-title').value = settings.widgetTitle
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

  # Calendar functions
  toggleCalendar = ->
    calendarContainer = domEl.querySelector('.calendar-container')
    calendarIcon = domEl.querySelector('.calendar-toggle')
    if calendarVisible
      calendarContainer.style.display = 'none'
      calendarIcon.classList.remove('active')
      calendarVisible = false
    else
      renderCalendar()
      calendarContainer.style.display = 'block'
      calendarIcon.classList.add('active')
      calendarVisible = true

  renderCalendar = ->
    calendarContainer = domEl.querySelector('.calendar-container')
    calendarContainer.innerHTML = ''
    month = currentCalendarDate.getMonth()
    year = currentCalendarDate.getFullYear()
    firstDay = new Date(year, month, 1).getDay()
    daysInMonth = new Date(year, month + 1, 0).getDate()

    # Header with navigation
    header = document.createElement('div')
    header.className = 'calendar-header'

    prevButton = document.createElement('button')
    prevButton.textContent = '←'
    prevButton.onclick = ->
      currentCalendarDate.setMonth(currentCalendarDate.getMonth() - 1)
      renderCalendar()

    nextButton = document.createElement('button')
    nextButton.textContent = '→'
    nextButton.onclick = ->
      currentCalendarDate.setMonth(currentCalendarDate.getMonth() + 1)
      renderCalendar()

    monthYear = document.createElement('span')
    monthYear.className = 'calendar-month-year'
    monthYear.textContent = currentCalendarDate.toLocaleString('default', { month: 'long', year: 'numeric' })

    header.appendChild(prevButton)
    header.appendChild(monthYear)
    header.appendChild(nextButton)
    calendarContainer.appendChild(header)

    # Weekdays
    weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
    weekdaysRow = document.createElement('div')
    weekdaysRow.className = 'calendar-weekdays'
    for dayName in weekdays
      day = document.createElement('div')
      day.className = 'calendar-weekday'
      day.textContent = dayName
      weekdaysRow.appendChild(day)
    calendarContainer.appendChild(weekdaysRow)

    # Days
    daysContainer = document.createElement('div')
    daysContainer.className = 'calendar-days'

    # Blank days before first day
    for i in [0...firstDay]
      blankDay = document.createElement('div')
      blankDay.className = 'calendar-day blank'
      daysContainer.appendChild(blankDay)

    # Actual days
    for date in [1..daysInMonth]
      day = document.createElement('div')
      day.className = 'calendar-day'
      day.textContent = date

      # Check if any task has a deadline on this date
      dateStr = new Date(year, month, date).toISOString().split('T')[0]
      hasDeadline = tasks.some((task) ->
        task.deadline?.startsWith(dateStr)
      )
      if hasDeadline
        # add deadline class to the day before this date
        previousDay = daysContainer.children[daysContainer.children.length - 1]
        if previousDay
          previousDay.classList.add('deadline')
      daysContainer.appendChild(day)

    calendarContainer.appendChild(daysContainer)

  # Event listeners
  domEl.querySelector('.add-task').addEventListener('click', showAddTaskForm)
  domEl.querySelector('.settings').addEventListener('click', showSettingsForm)
  domEl.querySelector('.calendar-toggle').addEventListener('click', toggleCalendar)
  domEl.querySelector('#save-task').addEventListener('click', addTask)
  domEl.querySelector('#save-settings').addEventListener('click', saveSettingsForm)
  domEl.querySelector('#cancel-add-task').addEventListener('click', -> domEl.querySelector('.add-task-form').style.display = 'none')
  domEl.querySelector('#cancel-settings').addEventListener('click', -> domEl.querySelector('.settings-form').style.display = 'none')
  domEl.querySelector('#cancel-edit-task').addEventListener('click', -> domEl.querySelector('.edit-task-form').style.display = 'none')
  domEl.querySelector('#confirm-complete-yes').addEventListener('click', completeTaskConfirmed)
  domEl.querySelector('#confirm-complete-no').addEventListener('click', hideConfirmCompleteTaskForm)

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