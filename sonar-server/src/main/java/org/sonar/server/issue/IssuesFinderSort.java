/*
 * SonarQube, open source software quality management tool.
 * Copyright (C) 2008-2013 SonarSource
 * mailto:contact AT sonarsource DOT com
 *
 * SonarQube is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 3 of the License, or (at your option) any later version.
 *
 * SonarQube is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */
package org.sonar.server.issue;

import com.google.common.base.Function;
import com.google.common.collect.Ordering;
import org.sonar.api.issue.IssueQuery;
import org.sonar.api.rule.Severity;
import org.sonar.core.issue.db.IssueDto;

import javax.annotation.Nonnull;

import java.util.Collection;
import java.util.Date;
import java.util.List;

class IssuesFinderSort {

  private List<IssueDto> issues;
  private IssueQuery query;

  public IssuesFinderSort(List<IssueDto> issues, @Nonnull IssueQuery query) {
    this.issues = issues;
    this.query = query;
  }

  public List<IssueDto> sort() {
    if (query.sort() != null) {
      IssueProcessor issueProcessor;
      switch (query.sort()) {
        case ASSIGNEE:
          issueProcessor = new AssigneeSortIssueProcessor();
          break;
        case SEVERITY:
          issueProcessor = new SeveritySortIssueProcessor();
          break;
        case STATUS:
          issueProcessor = new StatusSortIssueProcessor();
          break;
        case CREATION_DATE:
          issueProcessor = new CreationDateSortIssueProcessor();
          break;
        case UPDATE_DATE:
          issueProcessor = new UpdateDateSortIssueProcessor();
          break;
        case CLOSE_DATE:
          issueProcessor = new CloseDateSortIssueProcessor();
          break;
        default:
          throw new IllegalArgumentException("Cannot sort issues on field : " + query.sort().name());
      }
      return issueProcessor.sort(issues, query.asc());
    }
    return issues;
  }

  abstract static class IssueProcessor {
    abstract Function sortFieldFunction();

    abstract Ordering sortFieldOrdering(boolean ascending);

    final List<IssueDto> sort(Collection<IssueDto> issueDtos, boolean ascending) {
      Ordering<IssueDto> ordering = sortFieldOrdering(ascending).onResultOf(sortFieldFunction());
      return ordering.immutableSortedCopy(issueDtos);
    }
  }

  abstract static class TextSortIssueProcessor extends IssueProcessor {
    @Override
    Function sortFieldFunction() {
      return new Function<IssueDto, String>() {
        public String apply(IssueDto issueDto) {
          return sortField(issueDto);
        }
      };
    }

    abstract String sortField(IssueDto issueDto);

    @Override
    Ordering sortFieldOrdering(boolean ascending) {
      Ordering<String> ordering = Ordering.from(String.CASE_INSENSITIVE_ORDER).nullsLast();
      if (!ascending) {
        ordering = ordering.reverse();
      }
      return ordering;
    }
  }

  static class AssigneeSortIssueProcessor extends TextSortIssueProcessor {
    @Override
    String sortField(IssueDto issueDto) {
      return issueDto.getAssignee();
    }
  }

  static class StatusSortIssueProcessor extends TextSortIssueProcessor {
    @Override
    String sortField(IssueDto issueDto) {
      return issueDto.getStatus();
    }
  }

  static class SeveritySortIssueProcessor extends IssueProcessor {
    @Override
    Function sortFieldFunction() {
      return new Function<IssueDto, Integer>() {
        public Integer apply(IssueDto issueDto) {
          return Severity.ALL.indexOf(issueDto.getSeverity());
        }
      };
    }

    @Override
    Ordering sortFieldOrdering(boolean ascending) {
      Ordering<Integer> ordering = Ordering.<Integer>natural().nullsLast();
      if (!ascending) {
        ordering = ordering.reverse();
      }
      return ordering;
    }
  }

  abstract static class DateSortRowProcessor extends IssueProcessor {
    @Override
    Function sortFieldFunction() {
      return new Function<IssueDto, Date>() {
        public Date apply(IssueDto issueDto) {
          return sortField(issueDto);
        }
      };
    }

    abstract Date sortField(IssueDto issueDto);

    @Override
    Ordering sortFieldOrdering(boolean ascending) {
      Ordering<Date> ordering = Ordering.<Date>natural().nullsLast();
      if (!ascending) {
        ordering = ordering.reverse();
      }
      return ordering;
    }
  }

  static class CreationDateSortIssueProcessor extends DateSortRowProcessor {
    @Override
    Date sortField(IssueDto issueDto) {
      return issueDto.getIssueCreationDate();
    }
  }

  static class UpdateDateSortIssueProcessor extends DateSortRowProcessor {
    @Override
    Date sortField(IssueDto issueDto) {
      return issueDto.getIssueUpdateDate();
    }
  }

  static class CloseDateSortIssueProcessor extends DateSortRowProcessor {
    @Override
    Date sortField(IssueDto issueDto) {
      return issueDto.getIssueCloseDate();
    }
  }
}
