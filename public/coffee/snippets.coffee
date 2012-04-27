# Snippets of html -- possibly with some simple templating logic -- that we want to ship out to the client
# with the JS instead of causing extra requests.

window.Snippets =
  # Comment form html. This handles adding and editing comments
  commentForm: (inline, edit, hiddenFields) ->
    className = if edit then "commentEditForm" else "commentForm"
    submitValue = if edit then "Save Edit" else "Post Comment"
    header = if edit then "" else """
      <div class='heading'><span class='addAComment'>Add a comment</span></div>
      <input type='hidden' name='repo_name' value='#{hiddenFields.repoName}' />
      <input type='hidden' name='sha' value='#{hiddenFields.sha}' />
      <input type='hidden' name='filename' value='#{hiddenFields.filename}' />
      <input type='hidden' name='line_number' value='#{hiddenFields.lineNumber}' />
    """
    """
      <form class='#{className}' action='/comment' type='POST'>
        #{header}
        <textarea class='commentText' name='text'></textarea>
        <div class='commentControls'>
          <input class='commentSubmit' type='submit' value='#{submitValue}' />
          #{if inline then "<input class='commentCancel' type='button' value='Cancel' />"}
        </div>
      </form>"
    """

  maskingOverlay: "<div class='maskingOverlay'></div>"
  marginSizer: (maxLengthLine) -> "<span id='marginSizing'>#{maxLengthLine}</span>"
  approveButton: "<button id='approveButton' class='fancy'>Approve Commit</button>"
  disapproveButton: "<button id='disapproveButton' class='fancy' title='ಠ_ಠ'>Disapprove Commit</button>"
  approvalOverlay:
    """
    <div class="approvalPopup overlay"><div class="cellWrapper"><div class="container"></div></div></div>
    """
  approvalPopup: (approveOrDisapprove) ->
    "<div>Press <code>a</code> again to #{approveOrDisapprove} this commit.</div>"

  contextExpander: (isTop, isBottom, lineNumber, isIncremental) ->
    contextExtraClass = "topExpander" if isTop
    contextExtraClass = "bottomExpander" if isBottom
    contextExtraClass ?= ""
    expandInnerClass = if isIncremental then "incrementalExpansion" else ""

    view =
      context_extra_class: contextExtraClass
      expand_inner_class: expandInnerClass
      incremental: isIncremental
      line_number: lineNumber

    source = $("#context-expander-template").html()
    Mustache.render(source, view)
