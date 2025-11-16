"use client";

import { useState } from "react";
import NavBar from "../../components/layout/NavBar";
import RestList from "../../components/order/RestList";
import ProfilePanel from "../../components/layout/ProfilePanel";

export default function Page() {
    const [profileOpen, setProfileOpen] = useState(false);

    return (
        <>
            <NavBar onProfileClick={() => setProfileOpen(true)} />
            <RestList />

            <ProfilePanel
                open={profileOpen}
                onClose={() => setProfileOpen(false)}
            />
        </>
    );
}
