/* Open form for most common actions like comment, assign or plan */
function issueForm(actionType, elt) {
  var issueElt = $j(elt).closest('[data-issue-key]');
  var issueKey = issueElt.attr('data-issue-key');
  var actionsElt = issueElt.find('.code-issue-actions');
  var formElt = issueElt.find('.code-issue-form');

  actionsElt.addClass('hidden');
  formElt.html("<img src='" + baseUrl + "/images/loading-small.gif'>").removeClass('hidden');

  $j.ajax(baseUrl + "/issue/action_form/" + actionType + "?issue=" + issueKey)
    .done(function (msg) {
      formElt.html(msg);
      var focusField = formElt.find('[autofocus]');
      if (focusField != null) {
        focusField.focus();
      }
    })
    .fail(function (jqXHR, textStatus) {
      alert(textStatus);
    });
  return false;
}

/* Close forms opened through the method issueForm()  */
function closeIssueForm(elt) {
  var issueElt = $j(elt).closest('[data-issue-key]');
  var actionsElt = issueElt.find('.code-issue-actions');
  var formElt = issueElt.find('.code-issue-form');

  formElt.addClass('hidden');
  actionsElt.removeClass('hidden');
  return false;
}

/* Raise a Javascript event for Eclipse Web View */
function notifyIssueChange(issueKey) {
  $j(document).trigger('sonar.issue.updated', [issueKey]);
}

/* Submit forms opened through the method issueForm() */
function submitIssueForm(elt) {
  var formElt = $j(elt).closest('form');
  formElt.find('.loading').removeClass('hidden');
  formElt.find(':submit').prop('disabled', true);
  $j.ajax({
      type: "POST",
      url: baseUrl + '/issue/do_action',
      data: formElt.serialize()}
  ).success(function (htmlResponse) {
      var issueElt = formElt.closest('[data-issue-key]');
      var issueKey = issueElt.attr('data-issue-key');
      var replaced = $j(htmlResponse);
      issueElt.replaceWith(replaced);

      // re-enable the links opening modal popups
      replaced.find('.open-modal').modal();

      notifyIssueChange(issueKey)
    }
  ).fail(function (jqXHR, textStatus) {
      closeIssueForm(elt);
      alert(textStatus);
    });
  return false;
}

function doIssueAction(elt, action, parameters) {
  var issueElt = $j(elt).closest('[data-issue-key]');
  var issueKey = issueElt.attr('data-issue-key');

  issueElt.find('.code-issue-actions').html("<img src='" + baseUrl + "/images/loading.gif'>");
  parameters['issue'] = issueKey;

  $j.ajax({
      type: "POST",
      url: baseUrl + '/issue/do_action/' + action,
      data: parameters
    }
  ).success(function (htmlResponse) {
      var replaced = $j(htmlResponse);
      issueElt.replaceWith(replaced);

      // re-enable the links opening modal popups
      replaced.find('.open-modal').modal();

      notifyIssueChange(issueKey);
    }
  ).fail(function (jqXHR, textStatus) {
      closeIssueForm(elt);
      alert(textStatus);
    });
  return false;
}

function assignIssueToMe(elt) {
  var parameters = {'me': true};
  return doIssueAction(elt, 'assign', parameters)
}

function doIssueTransition(elt, transition) {
  var parameters = {'transition': transition};
  return doIssueAction(elt, 'transition', parameters)
}

function formDeleteIssueComment(elt) {
  var commentElt = $j(elt).closest("[data-comment-key]");
  var htmlId = commentElt.attr('id');
  var commentKey = commentElt.attr('data-comment-key');
  return openModalWindow(baseUrl + '/issue/delete_comment_form/' + commentKey + '?htmlId=' + htmlId, {});
}

function formEditIssueComment(elt) {
  var commentElt = $j(elt).closest("[data-comment-key]");
  var commentKey = commentElt.attr('data-comment-key');
  var issueElt = commentElt.closest('[data-issue-key]');

  issueElt.find('.code-issue-actions').addClass('hidden');
  commentElt.html("<img src='" + baseUrl + "/images/loading.gif'>");

  $j.get(baseUrl + "/issue/edit_comment_form/" + commentKey, function (html) {
    commentElt.html(html);
  });
  return false;
}

function doEditIssueComment(elt) {
  var formElt = $j(elt).closest('form');
  var issueElt = formElt.closest('[data-issue-key]');
  var issueKey = issueElt.attr('data-issue-key');
  $j.ajax({
    type: "POST",
    url: baseUrl + "/issue/edit_comment",
    data: formElt.serialize(),
    success: function (htmlResponse) {
      var replaced = $j(htmlResponse);
      issueElt.replaceWith(replaced);

      // re-enable the links opening modal popups
      replaced.find('.open-modal').modal();

      notifyIssueChange(issueKey);
    }
  });
  return false;
}

function refreshIssue(elt) {
  var issueElt = $j(elt).closest('[data-issue-key]');
  var issueKey = issueElt.attr('data-issue-key');
  $j.get(baseUrl + "/issue/show/" + issueKey, function (html) {
    var replaced = $j(html);
    issueElt.replaceWith(replaced);

    // re-enable the links opening modal popups
    replaced.find('.open-modal').modal();
  });
  return false;
}

/* Open form for creating a manual issue */
function openCIF(elt, componentId, line) {
  // TODO check if form is already displayed (by using form id)
  $j.get(baseUrl + "/issue/create_form?component=" + componentId + "&line=" + line, function (html) {
    $j(elt).closest('tr').find('td.line').append($j(html));
  });
  return false;
}

/* Close the form used for creating a manual issue */
function closeCreateIssueForm(elt) {
  $j(elt).closest('.code-issue-create-form').remove();
  return false;
}

/* Create a manual issue */
function submitCreateIssueForm(elt) {
  var formElt = $j(elt).closest('form');
  var loadingElt = formElt.find('.loading');

  loadingElt.removeClass('hidden');
  $j.ajax({
      type: "POST",
      url: baseUrl + '/issue/create',
      data: formElt.serialize()}
  ).success(function (html) {
      var replaced = $j(html);
      formElt.replaceWith(replaced);

      // enable the links opening modal popups
      replaced.find('.open-modal').modal();
    }
  ).error(function (jqXHR, textStatus, errorThrown) {
      var errorsElt = formElt.find('.code-issue-errors');
      errorsElt.html(jqXHR.responseText);
      errorsElt.removeClass('hidden');
    }
  ).always(function() {
      loadingElt.addClass('hidden');
    });
  return false;
}

