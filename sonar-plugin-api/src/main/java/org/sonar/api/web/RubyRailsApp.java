/*
 * Sonar, open source software quality management tool.
 * Copyright (C) 2008-2012 SonarSource
 * mailto:contact AT sonarsource DOT com
 *
 * Sonar is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 3 of the License, or (at your option) any later version.
 *
 * Sonar is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with Sonar; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02
 */
package org.sonar.api.web;

import com.google.common.annotations.Beta;
import org.sonar.api.ServerExtension;

/**
 * Complete Ruby on Rails application (controllers/helpers/models/views)
 * @since 2.15
 */
@Beta
public abstract class RubyRailsApp implements ServerExtension {

  /**
   * The app key, ie the plugin key. It does not relate to URLs at all.
   */
  public abstract String getKey();

  /**
   * The classloader path to the root directory. It contains a sub-directory named app/.
   * <p>For example if Ruby on Rails controllers are located in /org/sonar/sqale/app/controllers/,
   * then the path is /org/sonar/sqale</p>
   */
  public abstract String getPath();

}