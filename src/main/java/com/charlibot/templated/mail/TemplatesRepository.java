package com.charlibot.templated.mail;

import com.charlibot.templated.mail.model.TemplateDetailResponse;
import org.springframework.stereotype.Component;

import java.util.Collection;
import java.util.HashMap;
import java.util.Map;

@Component
public class TemplatesRepository {

  private final Map<Integer, TemplateDetailResponse> templates = new HashMap<>();

  public TemplateDetailResponse getTemplateById(final int templateId) {
    return templates.get(templateId);
  }

  public void insertTemplate(final TemplateDetailResponse templateDetailResponse) {
    templates.put(templateDetailResponse.getTemplateId(), templateDetailResponse);
  }

  public Collection<TemplateDetailResponse> listTemplates() {
    return templates.values();
  }
}
