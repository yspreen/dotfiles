
void print_all_menu_items(FILE *rsp)
{
#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 110000
    if (__builtin_available(macOS 11.0, *))
    {
        if (!CGRequestScreenCaptureAccess())
        {
            respond(rsp, "[!] Query (default_menu_items): Screen Recording "
                         "Permissions not given. Restart SketchyBar after granting "
                         "permissions.\n");
            return;
        }
    }

#endif
    CFArrayRef window_list = CGWindowListCopyWindowInfo(kCGWindowListOptionAll,
                                                        kCGNullWindowID);
    int window_count = CFArrayGetCount(window_list);

    float x_pos[window_count];
    char *owner[window_count];
    char *name[window_count];
    memset(owner, 0, sizeof(owner));
    memset(name, 0, sizeof(name));

    int item_count = 0;
    for (int i = 0; i < window_count; ++i)
    {
        x_pos[i] = -9999.f;
        CFDictionaryRef dictionary = CFArrayGetValueAtIndex(window_list, i);
        if (!dictionary)
            continue;

        CFStringRef owner_ref = CFDictionaryGetValue(dictionary,
                                                     kCGWindowOwnerName);

        CFNumberRef owner_pid_ref = CFDictionaryGetValue(dictionary,
                                                         kCGWindowOwnerPID);

        CFStringRef name_ref = CFDictionaryGetValue(dictionary, kCGWindowName);
        CFNumberRef layer_ref = CFDictionaryGetValue(dictionary, kCGWindowLayer);
        CFDictionaryRef bounds_ref = CFDictionaryGetValue(dictionary,
                                                          kCGWindowBounds);

        if (!name_ref || !owner_ref || !owner_pid_ref || !layer_ref || !bounds_ref)
            continue;

        long long int layer = 0;
        CFNumberGetValue(layer_ref, CFNumberGetType(layer_ref), &layer);
        uint64_t owner_pid = 0;
        CFNumberGetValue(owner_pid_ref,
                         CFNumberGetType(owner_pid_ref),
                         &owner_pid);

        if (layer != MENUBAR_LAYER)
            continue;
        CGRect bounds = CGRectNull;
        if (!CGRectMakeWithDictionaryRepresentation(bounds_ref, &bounds))
            continue;
        owner[item_count] = cfstring_copy(owner_ref);
        name[item_count] = cfstring_copy(name_ref);
        x_pos[item_count++] = bounds.origin.x;
    }

    if (item_count > 0)
    {
        fprintf(rsp, "[\n");
        int counter = 0;
        for (int i = 0; i < item_count; i++)
        {
            float current_pos = x_pos[0];
            uint32_t current_pos_id = 0;
            for (int j = 0; j < window_count; j++)
            {
                if (!name[j] || !owner[j])
                    continue;
                if (x_pos[j] > current_pos)
                {
                    current_pos = x_pos[j];
                    current_pos_id = j;
                }
            }

            if (!name[current_pos_id] || !owner[current_pos_id])
                continue;
            if (strcmp(name[current_pos_id], "") != 0)
            {
                if (counter++ > 0)
                {
                    fprintf(rsp, ", \n");
                }
                fprintf(rsp, "\t\"%s,%s\"", owner[current_pos_id],
                        name[current_pos_id]);
            }
            x_pos[current_pos_id] = -9999.f;
        }
        fprintf(rsp, "\n]\n");
        for (int i = 0; i < window_count; i++)
        {
            if (owner[i])
                free(owner[i]);
            if (name[i])
                free(name[i]);
        }
    }
    CFRelease(window_list);
}