RepoEdit =
  init: ->
    @form = $(".edit-repo-form")
    @form.submit =>
      this.submit()
      false
    @form.on("click", "span.delete-button", (event) => @deleteFileClicked(event))
    @newFilePath = @form.data("new-file-path")
    @bottomControlBox = $("#bottom-controls")
    @addFileButton = $("#add-file-button").click(=> @addFile(); false)
    @deletedFiles = []

  deleteFileClicked: (event) ->
    event.preventDefault()
    fileBlock = $(event.target).parents(".file-block")
    fileName = fileBlock.data("blob-name")
    @deletedFiles.push(fileName)
    fileBlock.fadeOut("fast", -> fileBlock.remove())

  addFile: ->
    addHTML = (html) =>
      html = $(html).hide()
      @bottomControlBox.before(html)
      html.fadeIn()
      $("html, body").animate({ scrollTop: $(document).height() }, "slow");
    $.get(@newFilePath, addHTML, "html")

  submit: ->
    renamedFileNames = $(".file-block[data-blob-name]").filter(->
      oldName = $(this).data("blob-name")
      newName = $(this).find('input[name="name"]').val()
      oldName != newName
    ).map(-> $(this).data("blob-name")).get()
    @deletedFiles.push.apply(@deletedFiles, renamedFileNames)

    files = $(".file-block").map((->
      $this = $(this)
      namebox = $this.find('input[name="name"]')
      {
        name: namebox.val(),
        text: $this.find("textarea").val()
      }
    )).get()
    data = { 
      files: files,
      deleted_paths: @deletedFiles,
      message: "Changed some files"
    }
    url = @form.attr("action")
    $.ajax(
      url: url
      type: "POST"
      data: JSON.stringify(data)
      success: (-> window.location = url)
      contentType: "application/json; charset=utf-8")

$(document).ready(-> RepoEdit.init())
